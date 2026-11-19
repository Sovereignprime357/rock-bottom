class_name RockBottomCharacterRoster
extends RefCounted
## Original authored cast, shared GPU skinning resources, independent instance poses.
## Actor origin stays at the feet. +Z is this art's forward; it is not camera -Z.

const Legacy = preload("res://scripts/character_art.gd")
const Profiles = preload("res://scripts/cast_profiles.gd")
const Sites = preload("res://scripts/site_cast_profiles.gd")
const DEFINITIONS := {
	&"tony":{"family":"human","height":1.96,"hip":0.76,"arm":0.62,"leg":0.64,"stride":1.10},
	&"pete":{"family":"human","height":1.77,"hip":0.66,"arm":0.43,"leg":0.54,"stride":0.86},
	&"yuri":{"family":"human","height":2.02,"hip":0.80,"arm":0.60,"leg":0.67,"stride":1.12},
	&"lurch":{"family":"human","height":2.24,"hip":1.01,"arm":0.88,"leg":0.89,"stride":1.45},
	&"brutus":{"family":"quadruped","height":0.95,"hip":0.43,"leg":0.34,"stride":0.72},
	&"possum":{"family":"quadruped","height":0.55,"hip":0.22,"leg":0.165,"stride":0.38}}
const HUMAN_ACTIONS: Array[StringName] = [&"talk",&"eat",&"inspect",&"windup",&"strike",&"grab",&"throw"]
const ANIMAL_ACTIONS: Array[StringName] = [&"windup",&"lunge",&"bite"]
static var _templates: Dictionary = {}
static var _materials: Dictionary = {}


static func supported_visuals() -> PackedStringArray:
	var result := PackedStringArray(["tony","pete","yuri","lurch","brutus","possum"])
	result.append_array(Profiles.supported_visuals())
	result.append_array(Sites.supported_visuals())
	return result


static func visual_for_actor(source_actor: Dictionary) -> StringName:
	return Profiles.visual_for_actor(source_actor)


static func visual_for_site(kind: StringName, site_record: Dictionary) -> StringName:
	return Sites.visual_for_site(kind,site_record)


static func definition(visual_id: StringName) -> Dictionary:
	if not DEFINITIONS.has(visual_id):
		var profile := Profiles.definition(visual_id)
		return Sites.definition(visual_id) if profile.is_empty() else profile
	var result: Dictionary = DEFINITIONS[visual_id].duplicate(true)
	result["visual_id"] = visual_id
	result["actions"] = HUMAN_ACTIONS.duplicate() if result.family == "human" else ANIMAL_ACTIONS.duplicate()
	result["forward"] = Vector3.BACK
	return result


static func create(visual_id: StringName, instance_seed: int = 0) -> Node3D:
	var def := definition(visual_id)
	if def.is_empty() or not prepare(visual_id): return null
	var source: Dictionary = _templates[visual_id]
	return _instantiate(visual_id,instance_seed,def,source)


static func prepare(visual_id: StringName) -> bool:
	var def := definition(visual_id)
	if def.is_empty(): return false
	if not _templates.has(visual_id):
		var built := _build_template(visual_id)
		if built.is_empty():
			push_error("Character construction failed: "+String(visual_id))
			return false
		_templates[visual_id] = built
	for companion: Dictionary in def.get("companions",[]):
		if not prepare(companion.visual_id): return false
	return true


static func is_prepared(visual_id: StringName) -> bool:
	if not _templates.has(visual_id): return false
	var def := definition(visual_id)
	if def.is_empty(): return false
	for companion: Dictionary in def.get("companions",[]):
		if not is_prepared(companion.visual_id): return false
	return true


static func preparation_stats() -> Dictionary:
	var result := {"templates":_templates.size(),"total":supported_visuals().size(),"build_usec":0,"weight_solves":0,"weight_cache_hits":0}
	for template: Dictionary in _templates.values():
		for key: String in ["build_usec","weight_solves","weight_cache_hits"]: result[key] += int(template.build_stats[key])
	return result


static func _instantiate(visual_id: StringName, instance_seed: int, def: Dictionary, source: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(visual_id)
	root.set_meta("visual_id",visual_id)
	root.set_meta("height",float(def.height))
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(skeleton)
	var rests: Array[Transform3D] = []
	var parents := PackedInt32Array()
	var lookup: Dictionary = {}
	for bone: Dictionary in source.bones:
		var index := skeleton.add_bone(bone.name)
		lookup[bone.name] = index
		skeleton.set_bone_parent(index,bone.parent)
		skeleton.set_bone_rest(index,bone.local)
		rests.append(bone.local)
		parents.append(bone.parent)
	skeleton.reset_bone_poses()
	var base_poses: Array[Transform3D] = rests.duplicate()
	for bone_name: String in def.get("base_pose",{}):
		var index: int = lookup[bone_name]
		var pose: Transform3D = base_poses[index]
		pose.basis *= Basis.from_euler(def.base_pose[bone_name])
		base_poses[index] = pose
		skeleton.set_bone_pose(index,pose)
	var layers: Array = [[],[],[],[]]
	for entry: Dictionary in source.meshes:
		var part := MeshInstance3D.new()
		part.name = "body_layer_%d" % entry.layer
		part.mesh = entry.mesh
		part.skin = source.skin
		part.skeleton = NodePath("../Skeleton")
		part.custom_aabb = AABB(Vector3(-1.8,-0.5,-2.8),Vector3(3.6,maxf(3.7,float(def.height)+0.7),5.6))
		root.add_child(part)
		layers[int(entry.layer)].append(part)
	var attachments: Array = []
	var prop_lookup: Dictionary = {}
	for entry: Dictionary in source.attachments:
		var part := (entry.scene as PackedScene).instantiate() as Node3D
		root.add_child(part)
		var binding := {"node":part,"bone":lookup[entry.bone],"offset":entry.offset}
		attachments.append(binding)
		prop_lookup[String(part.name)] = binding
	var markers: Dictionary = {}
	var marker_bones: Dictionary = {"head":"head"}
	if def.family == "human":
		marker_bones.merge({"left_arm":"left_shoulder","right_arm":"right_shoulder","left_leg":"left_hip","right_leg":"right_hip","left_grip":"left_wrist","right_grip":"right_wrist"})
	elif def.family in ["quadruped","mounted"]:
		for limb: String in ["front_left","front_right","back_left","back_right"]: marker_bones[limb] = limb
	elif def.family == "bird":
		marker_bones.merge({"left_wing":"left_wing","right_wing":"right_wing"})
		if bool(def.get("two_feet",false)): marker_bones.merge({"left_leg":"bird_left","right_leg":"bird_right"})
		else: marker_bones["single_leg"] = "single_leg"
	for marker_name: String in marker_bones:
		var marker := root.get_node_or_null(NodePath(marker_name)) as Node3D
		if marker == null:
			marker = Node3D.new()
			marker.name = marker_name
			root.add_child(marker)
		markers[marker_name] = {"node":marker,"bone":lookup[marker_bones[marker_name]]}
	var weighted_markers: Array = []
	if source.has("leash_binding"):
		var marker := Node3D.new(); marker.name = "leash_collar"; root.add_child(marker)
		var binding: Dictionary = source.leash_binding
		weighted_markers.append({"node":marker,"bones":binding.bones,"weights":binding.weights,"points":binding.points})
	var companions: Array = []
	var metrics: Dictionary = source.metrics.duplicate(true)
	for child_def: Dictionary in def.get("companions",[]):
		var child := create(child_def.visual_id,instance_seed+37+companions.size()*13)
		if child == null:
			root.free()
			return null
		child.name = String(child_def.get("name",child_def.visual_id))
		root.add_child(child)
		# The authored offset is in actor coordinates at rest. Only visual anatomy
		# follows this bone; each companion still owns an independent pose cache.
		var bone_index: int = lookup[child_def.bone]
		var anchor := Transform3D(Basis(Vector3.UP,float(child_def.get("yaw",0.0))),child_def.position)
		var offset: Transform3D = (source.bones[bone_index].global as Transform3D).affine_inverse()*anchor
		companions.append({"node":child,"bone":bone_index,"offset":offset,"anchor":anchor,"follow_bone":child_def.get("follow_bone",true),"action":child_def.action})
		var child_metrics: Dictionary = child.get_meta("roster_metrics")
		for key: String in ["meshes","surfaces","triangles","bones"]: metrics[key] += int(child_metrics[key])
	var rig := {"skeleton":skeleton,"rests":rests,"base_poses":base_poses,"parents":parents,"lookup":lookup,"attachments":attachments,"prop_lookup":prop_lookup,"companions":companions,
		"markers":markers,"weighted_markers":weighted_markers,"layers":layers,"definition":def,"time":0.0,
		"phase":0.0,"motion":0.0,"seed":float(posmod(instance_seed,997))/997.0*TAU,
		"detail":-1,"frame":0,"last_state":[],"pose_updates":0,"finger_updates":0,
		"applied_poses":base_poses.duplicate(),"bone_writes":0,"last_coats":3,"visibility_writes":0,
		"poses":base_poses.duplicate(),"pose_cache_enabled":true,"global_poses":base_poses.duplicate(),
		"global_valid":PackedByteArray(),"descendants":[],"global_cached_count":0,"global_pose_queries":0,"global_pose_solves":0,
		"attachment_globals":{},"attachments_dirty":true,"attachment_queries":0,"attachment_writes":0,
		"pose_deferred":false,"hidden_pose_skips":0}
	rig.global_valid.resize(parents.size())
	rig.global_valid.fill(0)
	for ancestor: int in range(parents.size()):
		var descendants := PackedInt32Array()
		for candidate: int in range(parents.size()):
			var current: int = candidate
			while current >= 0:
				if current == ancestor:
					descendants.append(candidate)
					break
				current = parents[current]
		rig.descendants.append(descendants)
	root.set_meta("roster_rig",rig)
	root.set_meta("roster_metrics",metrics)
	root.set_meta("roster_own_metrics",source.metrics.duplicate(true))
	_sync_attachments(rig)
	return root


static func _sync_attachments(rig: Dictionary) -> void:
	var refresh_weighted: bool = rig.attachments_dirty or not rig.pose_cache_enabled
	if rig.attachments_dirty:
		rig.attachment_globals.clear()
		rig.attachments_dirty = false
	for item: Dictionary in rig.attachments:
		_attachment_target(rig,item.node,_attachment_global(rig,item.bone)*item.offset)
	for item: Dictionary in rig.companions:
		_attachment_target(rig,item.node,_attachment_global(rig,item.bone)*item.offset if item.follow_bone else item.anchor)
	for key: String in rig.markers:
		if key == "head": continue # The face attachment is also the legacy head marker.
		var item: Dictionary = rig.markers[key]
		_attachment_target(rig,item.node,_attachment_global(rig,item.bone))
	if refresh_weighted:
		for item: Dictionary in rig.get("weighted_markers",[]):
			var point := Vector3.ZERO
			for index: int in range(4):
				point += (_attachment_global(rig,item.bones[index])*item.points[index])*float(item.weights[index])
			_attachment_target(rig,item.node,Transform3D(Basis.IDENTITY,point))


static func _attachment_global(rig: Dictionary, bone: int) -> Transform3D:
	if rig.pose_cache_enabled and rig.attachment_globals.has(bone): return rig.attachment_globals[bone]
	var value: Transform3D = (rig.skeleton as Skeleton3D).get_bone_global_pose(bone)
	rig.attachment_queries += 1
	rig.attachment_globals[bone] = value
	return value


static func _attachment_target(rig: Dictionary, node: Node3D, value: Transform3D) -> void:
	# Compare the node itself: a released prop intentionally differs from its
	# binding, even when the skeleton is unchanged on the next death frame.
	if node.transform == value: return
	node.transform = value
	rig.attachment_writes += 1


static func _raw_character(id: StringName) -> Node3D:
	# Reuse the original authored construction, before its static batching discards
	# part identity. Existing faces remain the same; legacy animation is never called.
	if not DEFINITIONS.has(id): return Sites.build_raw(id) if Profiles.definition(id).is_empty() else Profiles.build_raw(id)
	var raw := Node3D.new()
	match id:
		&"tony": Legacy._tony(raw)
		&"pete": Legacy._pete(raw)
		&"yuri": Legacy._yuri(raw)
		&"lurch": Legacy._lurch(raw)
		&"brutus": Legacy._brutus(raw)
		&"possum": Legacy._possum(raw)
	if id == &"pete":
		_apron(raw)
		Legacy._box(raw,Vector3(0,0.87,0.349),Vector3(0.23,0.13,0.015),"6c6648","apron_pocket")
		for side: float in [-1.0,1.0]:
			var low := Vector3(side*0.15,1.22,0.265)
			var high := Vector3(side*0.10,1.33,0.135)
			Legacy._panel(raw,PackedVector3Array([low-Vector3(0.014,0,0),low+Vector3(0.014,0,0),high+Vector3(0.014,0,0),high-Vector3(0.014,0,0)]),"b9ad7f","apron_strap")
	if id == &"yuri":
		var head := raw.get_node("head") as Node3D
		for part_name: String in ["cap","cap_peak"]:
			var part := head.get_node_or_null(NodePath(part_name))
			if part != null: part.free()
		var forearm := raw.get_node("left_arm/forearm") as Node3D
		var hubcap := Node3D.new()
		hubcap.name = "hubcap"
		forearm.add_child(hubcap)
		hubcap.position = Vector3(-0.025,-0.30,0.105)
		Legacy._oval(hubcap,Vector3.ZERO,Vector3(0.18,0.18,0.035),"837c65","rim")
		Legacy._oval(hubcap,Vector3(0,0,0.027),Vector3(0.125,0.125,0.016),"514d3f","dish")
		Legacy._oval(hubcap,Vector3(0,0,0.041),Vector3(0.055,0.055,0.02),"9d9273","hub")
	if id == &"tony":
		Legacy._garment(raw,[Vector4(0.215,0.73,0.145,0.13),Vector4(0.23,1.02,0.155,0.15),Vector4(0.26,1.30,0.16,0.15),Vector4(0.29,1.405,0.15,0.135),Vector4(0.24,1.445,0.13,0.12),Vector4(0.085,1.48,0.09,0.085)],Legacy.SKIN_PALE,"bare_torso")
	return raw


static func _apron(raw: Node3D) -> void:
	# A front cloth sheet follows the belly. A closed oval garment pinched its
	# sides and center behind the shirt, producing disconnected cream patches.
	var rows: Array[Vector3] = [Vector3(0.235,0.57,0.245),Vector3(0.275,0.78,0.327),Vector3(0.285,0.98,0.342),Vector3(0.245,1.15,0.318),Vector3(0.18,1.23,0.270)]
	var grid: Array[PackedVector3Array] = []
	for row: Vector3 in rows:
		var line := PackedVector3Array()
		for column: int in range(5):
			var fraction := float(column)/2.0-1.0
			line.append(Vector3(fraction*row.x,row.y,row.z-0.015*pow(fraction*row.x/0.285,2.0)))
		grid.append(line)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(grid.size()-1):
		for column: int in range(4):
			Legacy._triangle(surface,grid[row][column],grid[row][column+1],grid[row+1][column])
			Legacy._triangle(surface,grid[row][column+1],grid[row+1][column+1],grid[row+1][column])
	var apron := Legacy._instance(raw,surface.commit(),Vector3.ZERO,"b9ad7f","apron")
	var cloth := Legacy.Surfaces.material("fabric","b9ad7f").duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	apron.material_override = cloth


static func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = (parent as Node3D).transform*result
		parent = parent.get_parent()
	return result


static func _bone(data: Dictionary, bone_name: String, parent_name: String, global_rest: Transform3D) -> void:
	var index: int = data.bones.size()
	var parent: int = data.lookup.get(parent_name,-1)
	var local := global_rest
	if parent >= 0: local = (data.bones[parent].global as Transform3D).affine_inverse()*global_rest
	data.bones.append({"name":bone_name,"parent":parent,"global":global_rest,"local":local})
	data.lookup[bone_name] = index


static func _at(point: Vector3, basis: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis,point)


static func _build_bones(data: Dictionary, raw: Node3D, def: Dictionary) -> void:
	_bone(data,"root","",Transform3D.IDENTITY)
	if def.family == "assembly":
		_bone(data,"head","root",_relative(raw.get_node("head") as Node3D,raw))
		return
	if def.family == "object":
		_bone(data,"head","root",_relative(raw.get_node("head") as Node3D,raw))
		_bone(data,"mouth","head",_relative(raw.get_node("mouth") as Node3D,raw))
		return
	var human: bool = def.family == "human"
	var bird: bool = def.family == "bird"
	var hip: float = def.hip
	var head := raw.get_node("head") as Node3D
	_bone(data,"pelvis","root",_at(Vector3(0,hip,0 if human or bird else -0.22)))
	_bone(data,"spine","pelvis",_at(Vector3(0,hip+(0.22 if human else 0.02),0 if human else -0.05)))
	var chest_y: float = def.get("chest_y",hip+0.14 if def.family == "mounted" else head.position.y-(0.36 if human else 0.14))
	_bone(data,"chest","spine",_at(Vector3(0,chest_y,0 if human else 0.19)))
	_bone(data,"neck","chest",_at(def.get("neck_at",head.position-Vector3(0,0.18 if human else 0.05,0.04))))
	_bone(data,"head","neck",_at(head.position))
	if bird:
		if bool(def.get("two_feet",false)):
			for name_text: String in ["bird_left","bird_right"]:
				var leg := raw.get_node(name_text) as Node3D
				_bone(data,name_text,"pelvis",_relative(leg,raw))
				_bone(data,name_text+"_knee",name_text,_at(leg.position+Vector3(0,-0.085,-0.015)))
				_bone(data,name_text+"_ankle",name_text+"_knee",_at(leg.position+Vector3(0,-0.17,0.020)))
		else:
			var leg := raw.get_node("single_leg") as Node3D
			_bone(data,"single_leg","pelvis",_relative(leg,raw))
			_bone(data,"single_knee","single_leg",_at(leg.position+Vector3(0,-0.055,0.012)))
			_bone(data,"single_ankle","single_knee",_at(leg.position+Vector3(0,-0.095,0.02)))
		for part: String in ["left_wing","right_wing","tail"]: _bone(data,part,"chest" if part.ends_with("wing") else "pelvis",_relative(raw.get_node(part) as Node3D,raw))
	elif human:
		for side: String in ["left","right"]:
			var sign_value := -1.0 if side == "left" else 1.0
			var arm := raw.get_node(side+"_arm") as Node3D
			var elbow := arm.get_node("forearm") as Node3D
			var upper := _relative(arm,raw)
			var lower := _relative(elbow,raw)
			var hand := lower*_at(Vector3(sign_value*0.01,-float(def.arm)*0.47,0.03))
			_bone(data,side+"_shoulder","chest",upper)
			_bone(data,side+"_elbow",side+"_shoulder",lower)
			_bone(data,side+"_wrist",side+"_elbow",hand)
			_bone(data,side+"_fingers",side+"_wrist",hand*_at(Vector3(0,-0.075,0.025)))
			_bone(data,side+"_fingertips",side+"_fingers",hand*_at(Vector3(0,-0.112,0.027)))
			_bone(data,side+"_thumb",side+"_wrist",hand*_at(Vector3(-sign_value*0.06,-0.025,0.022)))
			_bone(data,side+"_thumbtip",side+"_thumb",hand*_at(Vector3(-sign_value*0.075,-0.065,0.04)))
			var leg := raw.get_node(side+"_leg") as Node3D
			var upper_leg := _relative(leg,raw)
			_bone(data,side+"_hip","pelvis",upper_leg)
			_bone(data,side+"_knee",side+"_hip",upper_leg*_at(Vector3(sign_value*0.024,-float(def.leg)*0.52,0.028)))
			_bone(data,side+"_ankle",side+"_knee",upper_leg*_at(Vector3(sign_value*0.04,-float(def.leg),0.03)))
	else:
		for limb: String in ["front_left","front_right","back_left","back_right"]:
			var leg := raw.get_node(limb) as Node3D
			var upper_leg := _relative(leg,raw)
			var sign_value := -1.0 if limb.ends_with("left") else 1.0
			_bone(data,limb,"chest" if limb.begins_with("front") else "pelvis",upper_leg)
			_bone(data,limb+"_knee",limb,upper_leg*_at(Vector3(sign_value*0.018,-float(def.leg)*0.52,0.008)))
			_bone(data,limb+"_ankle",limb+"_knee",upper_leg*_at(Vector3(sign_value*0.03,-float(def.leg),0.04)))
		var tail := raw.get_node("tail") as Node3D
		_bone(data,"tail","pelvis",_relative(tail,raw))
		_bone(data,"tail_mid","tail",_at(tail.position+(Vector3(0.04,-0.37,-0.11) if def.family == "mounted" else Vector3(0.06,-0.02,-0.24))))
		_bone(data,"tail_tip","tail_mid",_at(tail.position+(Vector3(0.10,-0.84,-0.11) if def.family == "mounted" else Vector3(0.20,-0.06,-0.43))))
		var jaw := raw.get_node_or_null("jaw") as Node3D
		if jaw != null: _bone(data,"jaw","head",_relative(jaw,raw))


static func _pack_attachment(data: Dictionary, raw: Node3D, node: Node3D, bone_name: String) -> void:
	var global_rest := _relative(node,raw)
	var bone_global: Transform3D = data.bones[data.lookup[bone_name]].global
	var offset := bone_global.affine_inverse()*global_rest
	Legacy._finish_rig(node)
	_set_owner(node,node)
	var scene := PackedScene.new()
	scene.pack(node)
	data.attachments.append({"scene":scene,"bone":bone_name,"offset":offset})
	data.skip.append(node)


static func _set_owner(node: Node, owner_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_root
		_set_owner(child,owner_root)


static func _build_template(id: StringName, memoize_weights: bool = true) -> Dictionary:
	var started := Time.get_ticks_usec()
	var raw := _raw_character(id)
	if raw == null: return {}
	var def := definition(id)
	var data := {"bones":[],"lookup":{},"attachments":[],"skip":[],"groups":{},"meshes":[],"errors":[],"skin_color":String(def.get("skin","")),
		"memoize_weights":memoize_weights,"weight_caches":{},"weight_solves":0,"weight_cache_hits":0}
	_build_bones(data,raw,def)
	if id == &"scrap_dog": data["leash_binding"] = _leash_binding(data,raw)
	_pack_attachment(data,raw,raw.get_node("head") as Node3D,"head")
	var jaw := raw.get_node_or_null("jaw") as Node3D
	if jaw != null: _pack_attachment(data,raw,jaw,"jaw")
	if id == &"pete": _pack_attachment(data,raw,raw.get_node("right_arm/forearm/hot_pocket") as Node3D,"right_wrist")
	if id == &"yuri": _pack_attachment(data,raw,raw.get_node("left_arm/forearm/hubcap") as Node3D,"left_wrist")
	for attachment: Dictionary in raw.get_meta("roster_attachments",[]):
		_pack_attachment(data,raw,raw.get_node(attachment.path) as Node3D,attachment.bone)
	if def.family == "bird":
		for part: String in ["left_wing","right_wing","tail"]: _pack_attachment(data,raw,raw.get_node(part) as Node3D,part)
	elif def.family == "object": _pack_attachment(data,raw,raw.get_node("mouth") as Node3D,"mouth")
	_collect(data,raw,raw,def,"torso")
	if not (data.errors as Array).is_empty():
		for error: String in data.errors: push_error(error)
		raw.free()
		return {}
	for key: String in data.groups:
		var group: Dictionary = data.groups[key]
		if (group.vertices as PackedVector3Array).is_empty(): continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = group.vertices
		arrays[Mesh.ARRAY_NORMAL] = group.normals
		arrays[Mesh.ARRAY_TEX_UV] = group.uvs
		arrays[Mesh.ARRAY_COLOR] = group.colors
		arrays[Mesh.ARRAY_BONES] = group.bones
		arrays[Mesh.ARRAY_WEIGHTS] = group.weights
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if mesh.get_surface_count() != 1:
			raw.free()
			return {}
		mesh.surface_set_material(0,group.material)
		data.meshes.append({"mesh":mesh,"layer":group.layer})
	var skin := Skin.new()
	for i: int in range(data.bones.size()): skin.add_bind(i,(data.bones[i].global as Transform3D).affine_inverse())
	data["skin"] = skin
	var metrics := {"meshes":data.meshes.size(),"surfaces":data.meshes.size(),"triangles":0,"bones":data.bones.size(),"max_weights":0 if (data.meshes as Array).is_empty() else 4}
	for entry: Dictionary in data.meshes:
		var arrays: Array = (entry.mesh as ArrayMesh).surface_get_arrays(0)
		metrics.triangles += floori(float((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3.0)
	for entry: Dictionary in data.attachments:
		var attachment := (entry.scene as PackedScene).instantiate()
		_add_metrics(attachment,metrics)
		attachment.free()
	data["metrics"] = metrics
	data.erase("groups")
	data.erase("skip")
	data.erase("weight_caches")
	raw.free()
	data["build_stats"] = {"build_usec":Time.get_ticks_usec()-started,"weight_solves":data.weight_solves,"weight_cache_hits":data.weight_cache_hits}
	data.erase("memoize_weights")
	data.erase("weight_solves")
	data.erase("weight_cache_hits")
	return data


static func _leash_binding(data: Dictionary,raw: Node3D) -> Dictionary:
	# Use an authored collar vertex and the same weight solve as the unchanged skin.
	# One immutable binding is cached with this template; no runtime mesh traversal.
	var part := raw.get_node("broken_link") as MeshInstance3D
	var transform: Transform3D = _relative(part,raw)
	var point := Vector3(0,INF,0)
	for surface: int in range(part.mesh.get_surface_count()):
		var vertices: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var at: Vector3 = transform*vertex
			if at.y < point.y: point = at
	var bounds: AABB = part.mesh.get_aabb()
	var chain: Array[String] = _chain(data,"torso",part,transform*(bounds.position+bounds.size*0.5))
	var weight: Array = _weights(data,chain,point)
	var points := PackedVector3Array()
	for index: int in range(4):
		points.append((data.bones[weight[0][index]].global as Transform3D).affine_inverse()*point)
	return {"bones":weight[0],"weights":weight[1],"points":points}


static func _add_metrics(node: Node, metrics: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		metrics.meshes += 1
		metrics.surfaces += mesh.get_surface_count()
		for surface: int in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			metrics.triangles += floori(float(indices.size() if not indices.is_empty() else vertices.size())/3.0)
	for child: Node in node.get_children(): _add_metrics(child,metrics)


static func _collect(data: Dictionary, raw: Node3D, node: Node3D, def: Dictionary, role: String) -> void:
	if node in data.skip: return
	var next_role := role
	var name_text := String(node.name)
	if name_text in ["left_arm","right_arm","left_leg","right_leg","front_left","front_right","back_left","back_right","tail","single_leg","bird_left","bird_right"]: next_role = name_text
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		var layer := _coat_layer(part,next_role,def.visual_id)
		_append_part(data,raw,part,next_role,layer)
		# Three sleeves are actual removable layers. A narrower bare arm remains.
		if def.visual_id == &"tony" and next_role.ends_with("_arm") and layer == 3:
			for extra: int in [0,1,2]: _append_part(data,raw,part,next_role,extra,0.62+0.125*float(extra),[Legacy.SKIN_PALE,"454c2e","8c6b3b"][extra])
	for child: Node in node.get_children():
		if child is Node3D: _collect(data,raw,child as Node3D,def,next_role)


static func _coat_layer(part: MeshInstance3D, role: String, id: StringName) -> int:
	if id != &"tony": return 0
	var color := (part.material_override as StandardMaterial3D).albedo_color.to_html(false)
	if role.ends_with("_leg"): return 0
	if color in ["604020","946b3c","3e2c1c","694725","4e341f"]: return 3
	if color in ["8c6b3b","b08e4e"]: return 2
	if color in ["454c2e","69703e","b29a56"]: return 1
	return 0


static func _uv_material(source: StandardMaterial3D, skin_override: bool = false) -> StandardMaterial3D:
	var chosen := Legacy._mat(Legacy.SKIN_PALE) if skin_override else source
	var key := str(chosen.albedo_texture.get_instance_id() if chosen.albedo_texture != null else 0)+":"+str(chosen.roughness)
	if not _materials.has(key):
		var material := chosen.duplicate() as StandardMaterial3D
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3(2,2,1)
		material.set_meta("slice_palette_batch",false)
		_materials[key] = material
	return _materials[key] as StandardMaterial3D


static func _append_part(data: Dictionary, raw: Node3D, part: MeshInstance3D, role: String, layer: int, radial_scale: float = 1.0, tint_override: String = "") -> void:
	var transform := _relative(part,raw)
	var normal_matrix := transform.basis.inverse().transposed()
	var source := part.material_override as StandardMaterial3D
	var material := _uv_material(source,tint_override == Legacy.SKIN_PALE)
	var color := source.albedo_color if tint_override.is_empty() else Color(tint_override)
	var key := str(layer)+":"+str(material.get_instance_id())
	if not data.groups.has(key): data.groups[key] = {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uvs":PackedVector2Array(),"colors":PackedColorArray(),"bones":PackedInt32Array(),"weights":PackedFloat32Array(),"material":material,"layer":layer}
	var group: Dictionary = data.groups[key]
	var bounds := part.mesh.get_aabb()
	var chain := _chain(data,role,part,transform*(bounds.position+bounds.size*0.5))
	var weights_cache: Dictionary = {}
	if bool(data.memoize_weights):
		# A chain is ordered: its segment projections and tie-breaking influence
		# order must match. Exact Vector3 keys preserve the original float inputs.
		var chain_key := "|".join(chain)
		if not data.weight_caches.has(chain_key): data.weight_caches[chain_key] = {}
		weights_cache = data.weight_caches[chain_key]
	for surface: int in range(part.mesh.get_surface_count()):
		var arrays := part.mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			data.errors.append("Missing vertex/normal data in "+String(part.name))
			return
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		if count%3 != 0 or vertices.size() != normals.size():
			data.errors.append("Invalid triangle/normal layout in "+String(part.name))
			return
		var refine: bool = not bool(part.get_meta("roster_no_refine",false)) and (vertices.size() >= 30 and role != "torso" or String(part.name) in ["bare_torso","shirt","work_jacket","coat_one","coat_two","coat_three","body"])
		for face: int in range(0,count,3):
			var points: Array[Vector3] = []
			var norms: Array[Vector3] = []
			for corner: int in range(3):
				var index: int = indices[face+corner] if not indices.is_empty() else face+corner
				var point := transform*vertices[index]
				if radial_scale != 1.0:
					var axis := _nearest_axis(data,chain,point)
					point = axis+(point-axis)*radial_scale
				points.append(point)
				norms.append((normal_matrix*normals[index]).normalized())
			if (points[1]-points[0]).cross(points[2]-points[0]).length_squared() < 0.000000000001: continue
			if refine:
				var ab := (points[0]+points[1])*0.5
				var bc := (points[1]+points[2])*0.5
				var ca := (points[2]+points[0])*0.5
				var nab := (norms[0]+norms[1]).normalized()
				var nbc := (norms[1]+norms[2]).normalized()
				var nca := (norms[2]+norms[0]).normalized()
				_add_triangle(data,group,[points[0],ab,ca],[norms[0],nab,nca],chain,color,weights_cache)
				_add_triangle(data,group,[ab,points[1],bc],[nab,norms[1],nbc],chain,color,weights_cache)
				_add_triangle(data,group,[ca,bc,points[2]],[nca,nbc,norms[2]],chain,color,weights_cache)
				_add_triangle(data,group,[ab,bc,ca],[nab,nbc,nca],chain,color,weights_cache)
			else: _add_triangle(data,group,points,norms,chain,color,weights_cache)


static func _chain(data: Dictionary, role: String, part: MeshInstance3D, center: Vector3) -> Array[String]:
	if role == "single_leg": return ["single_leg","single_knee","single_ankle"]
	if role in ["bird_left","bird_right"]: return [role,role+"_knee",role+"_ankle"]
	if role.ends_with("_arm"):
		var side := role.trim_suffix("_arm")
		if String(part.name) == "thumb": return [side+"_wrist",side+"_thumb",side+"_thumbtip"]
		# Anatomical ownership matters near the small joints: a global nearest-bone
		# solve bends the back of the palm with the fingertips and opens the fist.
		if String(part.name) == "hand": return [side+"_wrist"]
		var paint := part.material_override as StandardMaterial3D
		var skin: bool = paint.albedo_color.to_html(false) in [Legacy.SKIN,Legacy.SKIN_PALE,Legacy.SKIN_SHADE,data.skin_color]
		var wrist: Transform3D = data.bones[data.lookup[side+"_wrist"]].global
		if skin and (wrist.affine_inverse()*center).y < -0.08: return [side+"_fingers",side+"_fingertips"]
		return [side+"_shoulder",side+"_elbow",side+"_wrist"]
	if role.ends_with("_leg"):
		var side := role.trim_suffix("_leg")
		if String(part.name) in ["shoe","sole"] or part is MeshInstance3D and String(part.name).begins_with("lace"): return [side+"_ankle"]
		return [side+"_hip",side+"_knee",side+"_ankle"]
	if role in ["front_left","front_right","back_left","back_right"]: return [role,role+"_knee",role+"_ankle"]
	if role == "tail": return ["tail","tail_mid","tail_tip"]
	return ["pelvis","spine","chest","neck"]


static func _segment_point(point: Vector3, start: Vector3, end: Vector3) -> Vector3:
	var axis := end-start
	return start+axis*clampf((point-start).dot(axis)/maxf(axis.length_squared(),0.000001),0.0,1.0)


static func _axis(data: Dictionary, chain: Array[String], index: int, point: Vector3) -> Vector3:
	var start: Vector3 = data.bones[data.lookup[chain[index]]].global.origin
	var end: Vector3 = start+Vector3(0,-0.08,0.025)
	if index+1 < chain.size(): end = data.bones[data.lookup[chain[index+1]]].global.origin
	return _segment_point(point,start,end)


static func _nearest_axis(data: Dictionary, chain: Array[String], point: Vector3) -> Vector3:
	var nearest := point
	var distance: float = INF
	for i: int in range(chain.size()):
		var candidate := _axis(data,chain,i,point)
		var d := point.distance_squared_to(candidate)
		if d < distance:
			distance = d
			nearest = candidate
	return nearest


static func _weights(data: Dictionary, chain: Array[String], point: Vector3) -> Array:
	var ranked: Array[Vector2] = []
	for i: int in range(chain.size()):
		var distance := maxf(point.distance_to(_axis(data,chain,i,point)),0.018)
		ranked.append(Vector2(float(data.lookup[chain[i]]),1.0/pow(distance,4.0)))
	ranked.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.y > b.y)
	var total: float = 0.0
	for i: int in range(mini(4,ranked.size())): total += ranked[i].y
	var bones := PackedInt32Array([0,0,0,0])
	var weights := PackedFloat32Array([0,0,0,0])
	for i: int in range(mini(4,ranked.size())):
		bones[i] = int(ranked[i].x)
		weights[i] = ranked[i].y/total
	return [bones,weights]


static func _add_triangle(data: Dictionary, group: Dictionary, points: Array[Vector3], normals: Array[Vector3], chain: Array[String], color: Color, weights_cache: Dictionary) -> void:
	for i: int in range(3):
		var weight: Array
		if bool(data.memoize_weights) and weights_cache.has(points[i]):
			weight = weights_cache[points[i]]
			data.weight_cache_hits += 1
		else:
			weight = _weights(data,chain,points[i])
			data.weight_solves += 1
			if bool(data.memoize_weights): weights_cache[points[i]] = weight
		group.vertices.append(points[i])
		group.normals.append(normals[i])
		# Fixed at authoring time, before deformation. Repeated quiet fabric/skin
		# grain follows each triangle instead of sampling moving object coordinates.
		var normal := normals[i].abs()
		var uv := Vector2(points[i].x,points[i].y)
		if normal.x > normal.z and normal.x > normal.y: uv = Vector2(points[i].z,points[i].y)
		elif normal.y > normal.z: uv = Vector2(points[i].x,points[i].z)
		group.uvs.append(uv)
		group.colors.append(color)
		group.bones.append_array(weight[0])
		group.weights.append_array(weight[1])
