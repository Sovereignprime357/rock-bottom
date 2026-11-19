extends RefCounted
## Original site-resident authoring. No placement, AI, dialogue or resource authority.
## A site identity is its exact table kind/id/who; it is not an invented sprite alias.

const Art = preload("res://tests/reference_tony_character_art.gd")
const Cast = preload("res://tests/reference_tony_cast_profiles.gd")
const SITE_IDENTITIES := {
	"copper:cold_not":["dennis (nights)",&"dennis"],
	"copper:water_dept":["the raccoon quorum",&"raccoon_quorum"],
	"copper:rust_car":["transit authority dan",&"transit_dan"],
	"breakin:model_home":["the model family",&"model_family"],
	"breakin:spoil_bank":["the former teller",&"former_teller"],
	"breakin:sod_office":["the goose (manager)",&"goose_manager"],
	"breakin:drained_pool":["the lifeguard (still certified)",&"lifeguard"],
	"breakin:visitor_center":["the docent (self-guided)",&"docent"]}
const HUMAN_PROFILES := {
	&"dennis":{"shape":Vector4(1.84,0.77,0.34,0.25),"arm":0.59,"face":Vector4(1.13,1.15,0.91,-0.002),"head_scale":Vector3(1.04,0.98,1.02),"hair":"cap","hair_color":"494b36","wear":"uniform","shirt":"656447","pants":"403d2f","skin":"b09a6d","accent":"ac9d68","action":&"inspect"},
	&"transit_dan":{"shape":Vector4(1.95,0.91,0.255,0.17),"arm":0.64,"face":Vector4(0.94,1.05,1.30,-0.009),"head_scale":Vector3(0.98,1.06,1),"hair":"cap","hair_color":"4f4735","wear":"uniform","shirt":"716349","pants":"413c2f","skin":"b39b70","accent":"b7a675","action":&"write"},
	&"former_teller":{"shape":Vector4(1.81,0.84,0.23,0.16),"arm":0.58,"face":Vector4(0.98,0.86,1.22,0.009),"head_scale":Vector3(1.01,1.06,1),"hair":"receding","hair_color":"807456","wear":"workshirt","shirt":"b0a176","pants":"3b3c30","skin":"b9a27a","accent":"ac9d70","action":&"stamp"},
	&"docent":{"shape":Vector4(1.78,0.80,0.27,0.195),"arm":0.57,"face":Vector4(1.05,0.90,1.02,0.008),"head_scale":Vector3(1.02,1.01,1),"hair":"slick","hair_color":"51452e","wear":"cardigan","shirt":"89764b","pants":"4a4937","skin":"b59b6e","accent":"b9ab7c","action":&"wave"},
	&"lifeguard_seated":{"shape":Vector4(1.94,0.91,0.32,0.19),"arm":0.65,"face":Vector4(1.07,1.14,0.92,-0.004),"head_scale":Vector3(1.03,1.01,1),"hair":"cap","hair_color":"98854e","wear":"shorts","shirt":"a89a6b","pants":"7c4b36","skin":"ad8055","accent":"bbaa77","action":&"score"}}
const ACTIONS: Array[StringName] = [&"talk",&"inspect",&"read",&"write",&"serve",&"wave",&"salute",&"stamp",&"score"]
static var _skin_materials: Dictionary = {}
const MODEL_PROFILES := {
	&"model_father":{"shape":Vector4(1.78,0.83,0.28,0.19),"arm":0.56,"face":Vector4(1.05,1.10,1.02,0.0),"head_scale":Vector3(1,1,1),"hair":"slick","hair_color":"615239","wear":"open_jacket","shirt":"6d7050","pants":"464b35","skin":"b6aa7b","accent":"a99e70","action":&""},
	&"model_mother":{"shape":Vector4(1.70,0.79,0.255,0.19),"arm":0.54,"face":Vector4(1.00,0.90,0.88,0.007),"head_scale":Vector3(0.99,1,1),"hair":"bob","hair_color":"786040","wear":"dress","shirt":"8b694b","pants":"554734","skin":"b6aa7b","accent":"aea070","action":&""},
	&"model_son":{"shape":Vector4(1.29,0.54,0.19,0.14),"arm":0.40,"face":Vector4(1.03,0.87,0.73,0.004),"head_scale":Vector3(0.85,0.83,0.86),"hair":"quiff","hair_color":"76613f","wear":"workshirt","shirt":"93834f","pants":"5b5b3d","skin":"b6aa7b","accent":"b9ab7b","action":&""}}


static func supported_visuals(packet: String = "all") -> PackedStringArray:
	var result := PackedStringArray()
	if packet in ["all","b3","b3a"]:
		for id: StringName in HUMAN_PROFILES: result.append(String(id))
		result.append("lifeguard")
	if packet in ["all","b3","b3b"]:
		for id: StringName in MODEL_PROFILES: result.append(String(id))
		result.append_array(PackedStringArray(["model_family","quorum_raccoon","raccoon_quorum","goose_body","goose_manager"]))
	return result


static func visual_for_site(kind: StringName, site: Dictionary) -> StringName:
	if kind not in [&"copper",&"breakin"] or not site.get("id") is String or not site.get("who") is String: return &""
	var key := String(kind)+":"+String(site.id)
	if not SITE_IDENTITIES.has(key): return &""
	var entry: Array = SITE_IDENTITIES[key]
	if site.who != entry[0] or String(entry[1]) not in supported_visuals(): return &""
	return StringName(entry[1])


static func definition(id: StringName) -> Dictionary:
	if HUMAN_PROFILES.has(id) or MODEL_PROFILES.has(id):
		var p: Dictionary = (HUMAN_PROFILES[id] if HUMAN_PROFILES.has(id) else MODEL_PROFILES[id]).duplicate(true)
		var shape: Vector4 = p.shape
		p.merge({"family":"human","height":shape.x,"hip":shape.y,"leg":shape.y-0.12,"stride":(shape.y-0.12)*1.58,"visual_id":id,"actions":ACTIONS.duplicate(),"forward":Vector3.BACK,"site_resident":true})
		if id == &"lifeguard_seated" or MODEL_PROFILES.has(id):
			p["seated"] = true
			p["base_pose"] = {"left_hip":Vector3(-1.18,0,-0.08),"right_hip":Vector3(-1.18,0,0.08),"left_knee":Vector3(1.40,0,0),"right_knee":Vector3(1.40,0,0),"left_ankle":Vector3(-0.22,0,0),"right_ankle":Vector3(-0.22,0,0)}
		if MODEL_PROFILES.has(id):
			p["inert"] = true
			p["actions"] = []
			p.base_pose.merge({"left_shoulder":Vector3(-0.65,0,-0.08),"right_shoulder":Vector3(-0.65,0,0.08),"left_elbow":Vector3(-0.80,0,0),"right_elbow":Vector3(-0.80,0,0),"left_fingers":Vector3(-0.26,0,0),"right_fingers":Vector3(-0.26,0,0)})
			if id == &"model_son": p.base_pose.merge({"right_shoulder":Vector3(-0.80,0,0.16),"right_elbow":Vector3(-1.15,0,0)},true)
		return p
	if id == &"lifeguard":
		return {"family":"assembly","height":2.79,"hip":0.0,"leg":0.01,"stride":1.0,"visual_id":id,"actions":ACTIONS.duplicate(),"forward":Vector3.BACK,"site_resident":true,"action":&"score","companions":[{"visual_id":&"lifeguard_seated","name":"lifeguard_seated","position":Vector3(0,0.85,0),"bone":"root","follow_bone":false,"action":&""}]}
	if id == &"quorum_raccoon": return {"family":"quadruped","height":0.49,"hip":0.16,"leg":0.12,"stride":0.32,"visual_id":id,"actions":[&"talk",&"inspect",&"vote"],"forward":Vector3.BACK,"site_resident":true,"action":&"vote"}
	if id == &"goose_body": return {"family":"bird","two_feet":true,"height":1.15,"hip":0.20,"leg":0.17,"stride":0.41,"chest_y":0.45,"neck_at":Vector3(0,0.68,0.15),"visual_id":id,"actions":[&"talk",&"inspect",&"wave",&"bite"],"forward":Vector3.BACK,"site_resident":true,"action":&"talk"}
	if id in [&"model_family",&"raccoon_quorum",&"goose_manager"]:
		var p := {"family":"assembly","height":1.80,"hip":0.0,"leg":0.01,"stride":1.0,"visual_id":id,"actions":[],"forward":Vector3.BACK,"site_resident":true,"action":&"","companions":[]}
		if id == &"model_family":
			p["inert"] = true
			p.companions = [{"visual_id":&"model_father","name":"model_father","position":Vector3(-0.85,0,0),"yaw":PI*0.5,"bone":"root","follow_bone":false,"action":&""},{"visual_id":&"model_mother","name":"model_mother","position":Vector3(0.85,0.035,0),"yaw":-PI*0.5,"bone":"root","follow_bone":false,"action":&""},{"visual_id":&"model_son","name":"model_son","position":Vector3(0,0.22,-0.76),"bone":"root","follow_bone":false,"action":&""}]
		elif id == &"raccoon_quorum":
			p.height = 1.91
			p.actions = [&"talk",&"inspect",&"vote"]
			p.action = &"vote"
			for i: int in range(7):
				var at := Vector3(float(i%3-1)*0.51,1.0,-0.32 if i < 3 else 0.34)
				if i == 6: at = Vector3(-0.62,1.40,0.01)
				p.companions.append({"visual_id":&"quorum_raccoon","name":"raccoon_%d" % (i+1),"position":at,"yaw":-0.12+float(i%3)*0.12,"bone":"root","follow_bone":false,"action":&""})
		else:
			p.height = 1.98
			p.actions = [&"talk",&"inspect",&"wave",&"bite"]
			p.action = &"talk"
			p.companions = [{"visual_id":&"goose_body","name":"goose_body","position":Vector3(0,0.83,0),"bone":"root","follow_bone":false,"action":&""}]
		return p
	return {}


static func build_raw(id: StringName) -> Node3D:
	var p := definition(id)
	if p.is_empty(): return null
	var raw := Node3D.new()
	raw.name = String(id)
	raw.set_meta("height",p.height)
	raw.set_meta("roster_attachments",[])
	raw.set_meta("signature",String(id))
	if p.family == "human":
		Cast._human(raw,p)
		_human_signature(raw,p)
		if id == &"model_father": _blank_model_face(raw,p)
		elif id == &"model_son":
			var toast := Cast._held(raw,p,"right","raised_toast")
			Art._garment(toast,[Vector4(0.023,-0.07,0.023,0.023),Vector4(0.032,0.01,0.032,0.032)],"aa9d6e","toast_glass")
	elif id == &"quorum_raccoon": _raccoon(raw)
	elif id == &"goose_body": _goose(raw)
	else:
		var head := Art._node(raw,"head",Vector3.ZERO)
		match id:
			&"lifeguard": _elevated_chair(head)
			&"model_family": _dining_room(head)
			&"raccoon_quorum": _filing_cabinet(head)
			&"goose_manager": _manager_desk(head)
	Cast._surface_types(raw,p.family)
	if p.family == "human": _skin_surface(raw,p.skin)
	elif id in [&"quorum_raccoon",&"goose_body"]: _small_animal_details(raw)
	return raw


static func _small_animal_details(node: Node) -> void:
	# Authored tiny paws/toes/tail bands already contain their bend cross-sections.
	# Subdividing these again multiplies the seven-member quorum's geometry without
	# changing its silhouette or its independently weighted joints.
	if node is MeshInstance3D and (node as MeshInstance3D).mesh.get_aabb().size.length() < 0.23:
		node.set_meta("roster_no_refine",true)
	for child: Node in node.get_children(): _small_animal_details(child)


static func _skin_surface(node: Node, color: String) -> void:
	if node is MeshInstance3D and ((node as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.to_html(false) == color:
		if not _skin_materials.has(color):
			var material := Art.Surfaces.material("skin",color).duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.uv1_world_triplanar = false
			_skin_materials[color] = material
		(node as MeshInstance3D).material_override = _skin_materials[color]
	for child: Node in node.get_children(): _skin_surface(child,color)


static func _human_signature(raw: Node3D, p: Dictionary) -> void:
	var id: StringName = p.visual_id
	var width: float = p.shape.z
	var depth: float = p.shape.w
	var shoulder: float = float(p.height)-0.54*float(p.head_scale.y)
	var waist: float = float(p.hip)+0.08
	var head := raw.get_node("head") as Node3D
	match id:
		&"dennis":
			var thermos := Cast._chest_prop(raw,"empty_thermos",Vector3(0,waist+0.15,depth+0.19))
			Art._garment(thermos,[Vector4(0.057,-0.105,0.057,0.057),Vector4(0.062,0.065,0.062,0.062),Vector4(0.058,0.090,0.058,0.058)],"827d59","thermos")
			Art._garment(thermos,[Vector4(0.065,0.068,0.065,0.065),Vector4(0.065,0.098,0.065,0.065)],"aaa078","thermos_lip")
			Art._oval(thermos,Vector3(0,0.100,0),Vector3(0.052,0.002,0.052),"2c2c22","empty_interior")
			Art._box(raw,Vector3(-width*0.53,shoulder-0.14,depth*0.88+0.035),Vector3(0.12,0.06,0.016),"a99d70","night_watch_patch")
			var logbook := Art._node(raw,"shift_log",Vector3(width*0.76,waist-0.09,depth*0.52))
			Cast._board(logbook,Vector2(0.11,0.20),"6e6544")
		&"transit_dan":
			var badge := Art._node(raw,"peeling_badge",Vector3(-width*0.54,shoulder-0.14,depth+0.025))
			Art._box(badge,Vector3.ZERO,Vector3(0.105,0.145,0.008),"b2a77b","laminated_card")
			Art._panel(badge,PackedVector3Array([Vector3(0.012,0.072,0.007),Vector3(0.052,0.072,0.007),Vector3(0.061,0.038,0.032),Vector3(0.030,0.047,0.027)]),"c3b889","peeling_corner")
			Art._box(badge,Vector3(0,-0.015,0.008),Vector3(0.064,0.014,0.003),"605b42","badge_ink")
			var paper := Cast._chest_prop(raw,"transfer_slips",Vector3(-0.025,waist+0.16,depth+0.20))
			paper.rotation.x = -0.95
			Cast._board(paper,Vector2(0.25,0.24),"b4a77b")
			var punch := Cast._held(raw,p,"left","ticket_punch")
			Art._box(punch,Vector3(0,-0.02,0),Vector3(0.035,0.14,0.027),"8b896b","handle")
			Art._box(punch,Vector3(0,-0.06,0.024),Vector3(0.045,0.055,0.04),"6f725c","punch_jaw")
			_pencil(raw,p)
		&"former_teller":
			Cast._glasses(head,p.face.x,true)
			Art._coat_shell(raw,float(p.hip)-0.06,shoulder+0.085,Vector2(width*1.03,width*0.97),Vector2(depth+0.025,depth*0.89+0.02),"555640","banking_vest")
			Art._panel(raw,PackedVector3Array([Vector3(-0.115,shoulder+0.065,0.10),Vector3(0.115,shoulder+0.065,0.10),Vector3(0.07,waist+0.04,depth+0.035),Vector3(-0.07,waist+0.04,depth+0.035)]),"b2a57b","shirt_front")
			Art._panel(raw,PackedVector3Array([Vector3(-0.023,shoulder+0.042,0.118),Vector3(0.023,shoulder+0.042,0.118),Vector3(0.034,waist+0.10,depth+0.044),Vector3(0,waist+0.075,depth+0.048),Vector3(-0.034,waist+0.10,depth+0.044)]),"6a4933","tie")
			var paper := Cast._chest_prop(raw,"bank_papers",Vector3(-0.02,waist+0.12,depth+0.24))
			paper.rotation.x = -0.95
			Cast._board(paper,Vector2(0.28,0.26),"b7aa7c")
			var stamp := Cast._held(raw,p,"right","rubber_stamp")
			Art._garment(stamp,[Vector4(0.022,-0.075,0.022,0.022),Vector4(0.024,0.015,0.025,0.025),Vector4(0.044,0.04,0.035,0.035)],"765335","stamp_handle")
			Art._box(stamp,Vector3(0,-0.095,0),Vector3(0.105,0.035,0.06),"424334","stamp_base")
			var shoe := Cast._held(raw,p,"left","shoe_drawer",Vector3(0,-0.07,0.025))
			Art._garment(shoe,[Vector4(0.06,-0.055,0.13,0.065),Vector4(0.065,-0.025,0.13,0.075),Vector4(0.052,0.04,0.065,0.065)],"594633","old_shoe")
			Art._oval(shoe,Vector3(0,0.044,0),Vector3(0.044,0.005,0.058),"24261e","cash_drawer_opening")
		&"docent":
			var brochure := Cast._chest_prop(raw,"brochure",Vector3(-0.045,waist+0.18,depth+0.18))
			brochure.rotation.x = -0.55
			Cast._board(brochure,Vector2(0.23,0.25),"b8aa78")
			var folded := Art._node(brochure,"folded_panel",Vector3(0.11,0,0))
			folded.rotation.y = -0.45
			Cast._board(folded,Vector2(0.13,0.25),"a99a69")
			Art._box(raw,Vector3(-width*0.47,shoulder-0.14,depth+0.025),Vector3(0.12,0.066,0.012),"b8ab7a","visitor_badge")
			Art._box(raw,Vector3(-width*0.47,shoulder-0.15,depth+0.034),Vector3(0.075,0.009,0.003),"59583c","badge_ink")
		&"lifeguard_seated":
			var whistle := Art._node(raw,"whistle",Vector3(0,shoulder-0.20,depth+0.035))
			Art._box(whistle,Vector3.ZERO,Vector3(0.034,0.035,0.050),"a49b71","whistle_body")
			for side: float in [-1.0,1.0]: Art._between(raw,Vector3(side*0.07,shoulder+0.07,0.10),whistle.position,0.004,0.004,"5b5137","lanyard")
			var score := Cast._held(raw,p,"right","score_card",Vector3(0.0,-0.08,0.02))
			Art._box(score,Vector3.ZERO,Vector3(0.20,0.26,0.014),"bbaa77","score_board")
			for bar: Vector4 in [Vector4(0.0,0.080,0.085,0.017),Vector4(-0.043,0.038,0.017,0.085),Vector4(0.0,0.0,0.085,0.017),Vector4(-0.043,-0.043,0.017,0.085),Vector4(0.043,-0.043,0.017,0.085),Vector4(0.0,-0.085,0.085,0.017)]:
				Art._box(score,Vector3(bar.x,bar.y,0.010),Vector3(bar.z,bar.w,0.004),"4b4933","six")


static func _blank_model_face(raw: Node3D, p: Dictionary) -> void:
	var old_head := raw.get_node("head") as Node3D
	var at := old_head.position
	var size := old_head.scale
	old_head.free()
	var head := Art._node(raw,"head",at)
	head.scale = size
	var rings: Array[PackedVector3Array] = [Art._face_ring(0.045,-0.215,0.055,0.06),Art._face_ring(0.13,-0.18,0.13,0.12),Art._face_ring(0.17,-0.09,0.15,0.155),Art._face_ring(0.18,-0.04,0.155,0.165,0.055),Art._face_ring(0.18,0.04,0.16,0.17,0.02),Art._face_ring(0.17,0.13,0.16,0.16),Art._face_ring(0.14,0.195,0.13,0.13),Art._face_ring(0.07,0.225,0.065,0.065),Art._face_ring(0.01,0.232,0.01,0.01)]
	Art._instance(head,Art._sculpt_mesh(rings,0.76),Vector3.ZERO,p.skin,"eyeless_face")
	for side: float in [-1.0,1.0]:
		Art._panel(head,PackedVector3Array([Vector3(side*0.17,0.04,0.015),Vector3(side*0.21,0.045,0.005),Vector3(side*0.215,-0.045,0.005),Vector3(side*0.17,-0.055,0.025)]),p.skin,"ear")
	Art._panel(head,PackedVector3Array([Vector3(-0.06,-0.12,0.155),Vector3(0.06,-0.12,0.155),Vector3(0.055,-0.126,0.157),Vector3(-0.055,-0.126,0.157)]),"76694c","mouth")
	Cast._hair(head,p)


static func _dining_room(parent: Node3D) -> void:
	var table := Art._node(parent,"dinner_table",Vector3.ZERO)
	Art._box(table,Vector3(0,0.78,0),Vector3(1.25,0.065,1.02),"7d6544","table_top")
	for x: float in [-0.50,0.50]:
		for z: float in [-0.39,0.39]: Art._box(table,Vector3(x,0.39,z),Vector3(0.07,0.77,0.07),"6b573b","table_leg")
	for i: int in range(4):
		var angle := float(i)*PI*0.5
		var chair := Art._node(parent,"empty_fourth_chair" if i == 0 else "dining_chair_%d" % i,Vector3(sin(angle)*0.85,0,cos(angle)*0.76))
		chair.rotation.y = angle+PI
		Art._box(chair,Vector3(0,0.68,0),Vector3(0.43,0.045,0.39),"82724d","seat")
		Art._box(chair,Vector3(0,1.01,-0.19),Vector3(0.43,0.38,0.036),"8b7a50","back")
		for side: float in [-1.0,1.0]:
			for z: float in [-0.15,0.15]: Art._box(chair,Vector3(side*0.18,0.34,z),Vector3(0.04,0.66,0.04),"6a5b3d","leg")
		var plate_at := Vector3(sin(angle)*0.41,0.825,cos(angle)*0.34)
		Art._oval(table,plate_at,Vector3(0.13,0.012,0.13),"b5a675","plate")
		Art._oval(table,plate_at+Vector3(0.015,0.022,0),Vector3(0.065,0.024,0.045),"897344","plastic_dinner")
	var fruit := Art._node(table,"fruit_bowl",Vector3(0,0.84,0))
	Art._garment(fruit,[Vector4(0.10,-0.025,0.10,0.10),Vector4(0.16,0.045,0.15,0.15)],"a08f5b","bowl")
	for i: int in range(4): Art._oval(fruit,Vector3(sin(float(i)*1.8)*0.075,0.06,cos(float(i)*1.8)*0.065),Vector3(0.047,0.048,0.045),"8b5941" if i == 0 else "9c8a45","fruit")


static func _filing_cabinet(parent: Node3D) -> void:
	var cabinet := Art._node(parent,"filing_cabinet",Vector3.ZERO)
	Art._box(cabinet,Vector3(0,0.48,0),Vector3(1.55,0.94,1.25),"6c705b","cabinet")
	Art._box(cabinet,Vector3(0,0.975,0),Vector3(1.60,0.045,1.30),"848468","cabinet_top")
	for row: int in range(3):
		var y := 0.19+float(row)*0.28
		Art._box(cabinet,Vector3(0,y,0.633),Vector3(1.44,0.245,0.022),"757761","drawer")
		Art._box(cabinet,Vector3(0,y,0.657),Vector3(0.20,0.044,0.038),"4c5343","drawer_handle")
		Art._box(cabinet,Vector3(-0.43,y+0.045,0.649),Vector3(0.18,0.066,0.009),"a89f70","label")
	Art._box(cabinet,Vector3(-0.62,1.20,0),Vector3(0.36,0.40,0.55),"8b825a","file_stack")
	var can := Art._node(cabinet,"evidence_can",Vector3(0.54,1.07,0.01))
	Art._garment(can,[Vector4(0.047,-0.07,0.047,0.047),Vector4(0.047,0.07,0.047,0.047)],"a19d75","can")
	Art._box(can,Vector3(0,0,0.046),Vector3(0.05,0.045,0.005),"777244","unmarked_label")


static func _manager_desk(parent: Node3D) -> void:
	var desk := Art._node(parent,"manager_desk",Vector3.ZERO)
	Art._box(desk,Vector3(0,0.79,0),Vector3(1.15,0.07,0.76),"84704c","desktop")
	for side: float in [-1.0,1.0]: Art._box(desk,Vector3(side*0.43,0.39,0),Vector3(0.15,0.77,0.65),"6c5d40","desk_support")
	Art._box(desk,Vector3(0,0.58,-0.31),Vector3(0.85,0.35,0.035),"766747","modesty_panel")
	Art._box(desk,Vector3(-0.34,0.845,0.08),Vector3(0.25,0.025,0.27),"b2a578","manager_papers")
	Art._box(desk,Vector3(0.37,0.87,0.15),Vector3(0.19,0.10,0.14),"777759","petty_cash_tin")


static func _pencil(raw: Node3D, p: Dictionary) -> void:
	var pencil := Cast._held(raw,p,"right","pencil")
	pencil.rotation.z = PI
	Art._between(pencil,Vector3(0,-0.06,0),Vector3(0,0.09,0),0.006,0.004,"a28a44","pencil")


static func _elevated_chair(parent: Node3D) -> void:
	var chair := Art._node(parent,"lifeguard_chair",Vector3.ZERO)
	Art._box(chair,Vector3(0,1.73,0),Vector3(0.66,0.055,0.55),"8d8052","seat")
	Art._box(chair,Vector3(0,2.03,-0.25),Vector3(0.65,0.43,0.045),"96875a","back")
	for side: float in [-1.0,1.0]:
		for z: float in [-0.26,0.26]: Art._between(chair,Vector3(side*0.40,0.035,z*1.6),Vector3(side*0.30,1.76,z),0.027,0.023,"817754","chair_leg")
		Art._between(chair,Vector3(side*0.30,1.76,-0.25),Vector3(side*0.30,2.28,-0.25),0.024,0.024,"817754","back_post")
		Art._between(chair,Vector3(side*0.34,1.99,-0.22),Vector3(side*0.34,1.99,0.35),0.024,0.024,"8a7c53","armrest")
	for step: int in range(5): Art._box(chair,Vector3(0,0.28+float(step)*0.28,0.40-float(step)*0.025),Vector3(0.73,0.04,0.17),"8a7b50","ladder_step")


static func _raccoon(raw: Node3D) -> void:
	# One compact shoulder/back form and one continuous tapered face. The eye mask
	# follows the facial planes; neither the eyes nor the muzzle are bead spheres.
	Art._animal_form(raw,[Vector4(0.075,0.20,0.082,0.074),Vector4(0.126,0.10,0.118,0.102),Vector4(0.140,-0.065,0.132,0.112),Vector4(0.116,-0.205,0.108,0.090),Vector4(0.045,-0.275,0.051,0.044)],0.265,"77745e","body")
	var head := Art._node(raw,"head",Vector3(0,0.34,0.18))
	Art._animal_form(head,[Vector4(0.015,0.178,0.015,0.013),Vector4(0.038,0.132,0.031,0.027),Vector4(0.075,0.071,0.061,0.048),Vector4(0.108,0.007,0.090,0.072),Vector4(0.094,-0.068,0.085,0.068),Vector4(0.035,-0.112,0.039,0.034)],0,"aaa17c","head_shape",[-0.034,-0.021,-0.008,0.0,0.0,0.0])
	Art._animal_form(head,[Vector4(0.012,0.190,0.010,0.009),Vector4(0.022,0.178,0.015,0.013),Vector4(0.019,0.165,0.014,0.012)],-0.034,"303128","nose",[],0.55)
	Art._panel(head,PackedVector3Array([Vector3(-0.031,-0.045,0.144),Vector3(0,-0.052,0.167),Vector3(0.031,-0.045,0.144),Vector3(0,-0.056,0.164)]),"4c4533","mouth")
	for side: float in [-1.0,1.0]:
		Art._panel(head,PackedVector3Array([Vector3(side*0.034,0.013,0.139),Vector3(side*0.051,0.039,0.111),Vector3(side*0.086,0.043,0.065),Vector3(side*0.106,0.026,0.024),Vector3(side*0.102,-0.007,0.028),Vector3(side*0.072,-0.010,0.087),Vector3(side*0.046,-0.016,0.123)]),"3c3d31","eye_mask")
		Art._panel(head,PackedVector3Array([Vector3(side*0.055,0.024,0.111),Vector3(side*0.068,0.037,0.095),Vector3(side*0.084,0.036,0.074),Vector3(side*0.090,0.025,0.065),Vector3(side*0.077,0.017,0.085),Vector3(side*0.062,0.017,0.105)]),"bdb283","eye")
		Art._panel(head,PackedVector3Array([Vector3(side*0.071,0.035,0.093),Vector3(side*0.079,0.034,0.083),Vector3(side*0.079,0.020,0.084),Vector3(side*0.071,0.020,0.095)]),"262a22","pupil")
		Art._panel(head,PackedVector3Array([Vector3(side*0.052,0.029,0.114),Vector3(side*0.068,0.042,0.097),Vector3(side*0.087,0.041,0.072),Vector3(side*0.089,0.035,0.069),Vector3(side*0.069,0.036,0.098)]),"34382b","upper_lid")
		Art._organic_link(head,[Vector3(side*0.074,0.059,-0.054),Vector3(side*0.092,0.106,-0.052),Vector3(side*0.094,0.137,-0.046)],[Vector2(0.035,0.020),Vector2(0.029,0.018),Vector2(0.009,0.007)],"6b6b55","ear")
		Art._panel(head,PackedVector3Array([Vector3(side*0.076,0.077,-0.031),Vector3(side*0.078,0.108,-0.032),Vector3(side*0.092,0.123,-0.033),Vector3(side*0.108,0.105,-0.032),Vector3(side*0.105,0.078,-0.030)]),"a49a74","ear_inset")
		for z: float in [0.12,-0.18]:
			var leg := Art._node(raw,("front_" if z > 0 else "back_")+("left" if side < 0 else "right"),Vector3(side*0.096,0.16,z))
			Art._organic_link(leg,[Vector3.ZERO,Vector3(side*0.012,-0.055,0.0),Vector3(side*0.022,-0.120,0.025)],[Vector2(0.041,0.045),Vector2(0.030,0.033),Vector2(0.019,0.023)],"66634f","leg")
			var palm := Art._animal_form(leg,[Vector4(0.024,0.074,0.012,0.010),Vector4(0.033,0.048,0.018,0.012),Vector4(0.019,0.023,0.016,0.011)],-0.135,"534f40","paw")
			palm.position.x = side*0.022
			for digit: int in range(4):
				var x: float = side*0.022+float(digit)*0.014-0.021
				var reach: float = 0.103+0.010*sin(float(digit)*PI/3.0)
				Art._organic_link(leg,[Vector3(x,-0.137,0.059),Vector3(x+float(digit)*0.002-0.003,-0.143,0.084),Vector3(x+float(digit)*0.003-0.0045,-0.144,reach)],[Vector2(0.0075,0.008),Vector2(0.0065,0.007),Vector2(0.004,0.004)],"5e5744","finger")
			Art._organic_link(leg,[Vector3(side*0.048,-0.132,0.034),Vector3(side*0.063,-0.140,0.049),Vector3(side*0.066,-0.143,0.066)],[Vector2(0.008,0.008),Vector2(0.007,0.007),Vector2(0.004,0.004)],"5e5744","thumb")
	var tail := Art._node(raw,"tail",Vector3(0,0.24,-0.25))
	# Adjacent closed cross-sections share the same plane, giving genuine rings
	# without raised torus bands or a stack of unrelated cylinders.
	var tail_centers: Array[Vector3] = [Vector3.ZERO,Vector3(0.018,-0.013,-0.070),Vector3(0.043,-0.033,-0.140),Vector3(0.073,-0.054,-0.205),Vector3(0.110,-0.071,-0.263),Vector3(0.151,-0.083,-0.309),Vector3(0.184,-0.084,-0.337)]
	var tail_sizes: Array[Vector2] = [Vector2(0.054,0.052),Vector2(0.058,0.055),Vector2(0.056,0.052),Vector2(0.049,0.046),Vector2(0.040,0.037),Vector2(0.027,0.025),Vector2(0.007,0.007)]
	var tail_axis := (tail_centers[-1]-tail_centers[0]).normalized()
	var tail_basis := Quaternion(Vector3.UP,tail_axis)
	for band: int in range(tail_centers.size()-1):
		var rings: Array[PackedVector3Array] = []
		for row: int in [band,band+1]:
			var ring := PackedVector3Array()
			for point: int in range(10):
				var angle := TAU*float(point)/10.0
				ring.append(tail_centers[row]+tail_basis*Vector3(sin(angle)*tail_sizes[row].x,0,cos(angle)*tail_sizes[row].y))
			rings.append(ring)
		Art._instance(tail,Art._sculpt_mesh(rings,0.88),Vector3.ZERO,"4b4c3c" if band%2 == 0 else "a09670","tail_fur")


static func _goose(raw: Node3D) -> void:
	Art._animal_form(raw,[Vector4(0.125,0.275,0.130,0.100),Vector4(0.215,0.14,0.205,0.150),Vector4(0.235,-0.055,0.220,0.168),Vector4(0.185,-0.255,0.165,0.110),Vector4(0.080,-0.395,0.065,0.049)],0.375,"b7ad84","body")
	Art._organic_link(raw,[Vector3(0,0.48,0.14),Vector3(0,0.62,0.18),Vector3(0,0.79,0.12),Vector3(0,0.94,0.14),Vector3(0,1.025,0.18)],[Vector2(0.100,0.110),Vector2(0.072,0.074),Vector2(0.048,0.055),Vector2(0.052,0.055),Vector2(0.060,0.066)],"c0b58a","neck")
	var head := Art._node(raw,"head",Vector3(0,1.02,0.18))
	Art._animal_form(head,[Vector4(0.036,0.145,0.037,0.034),Vector4(0.066,0.085,0.068,0.057),Vector4(0.089,0.005,0.095,0.078),Vector4(0.069,-0.072,0.073,0.060),Vector4(0.025,-0.110,0.025,0.025)],0.009,"c4b98d","head_shape")
	Art._animal_form(head,[Vector4(0.044,0.330,0.012,0.011),Vector4(0.059,0.280,0.022,0.015),Vector4(0.058,0.180,0.029,0.022),Vector4(0.043,0.115,0.032,0.029)],-0.018,"a17c3f","beak")
	Art._animal_form(head,[Vector4(0.040,0.337,0.008,0.007),Vector4(0.046,0.321,0.012,0.010)],-0.018,"6c5630","bill_tip",[],0.55)
	for side: float in [-1.0,1.0]:
		Art._panel(head,PackedVector3Array([Vector3(side*0.054,0.027,0.096),Vector3(side*0.065,0.045,0.081),Vector3(side*0.081,0.040,0.049),Vector3(side*0.086,0.023,0.033),Vector3(side*0.075,0.013,0.054),Vector3(side*0.060,0.014,0.087)]),"3b3c2e","eye")
		Art._panel(head,PackedVector3Array([Vector3(side*0.064,0.036,0.086),Vector3(side*0.070,0.037,0.076),Vector3(side*0.073,0.024,0.072),Vector3(side*0.066,0.024,0.083)]),"a89a5d","iris")
		Art._panel(head,PackedVector3Array([Vector3(side*0.067,0.035,0.083),Vector3(side*0.071,0.034,0.077),Vector3(side*0.072,0.025,0.077),Vector3(side*0.068,0.025,0.083)]),"292d24","pupil")
		Art._panel(head,PackedVector3Array([Vector3(side*0.053,0.034,0.098),Vector3(side*0.065,0.050,0.084),Vector3(side*0.082,0.045,0.049),Vector3(side*0.083,0.039,0.047),Vector3(side*0.065,0.044,0.086)]),"ad9f75","upper_lid")
		Art._panel(head,PackedVector3Array([Vector3(side*0.034,-0.003,0.236),Vector3(side*0.047,-0.004,0.220),Vector3(side*0.048,-0.010,0.221),Vector3(side*0.036,-0.010,0.239)]),"6d592f","nostril")
		Art._between(head,Vector3(side*0.052,-0.026,0.165),Vector3(side*0.043,-0.028,0.322),0.0018,0.0013,"746035","bill_seam")
		var leg := Art._node(raw,"bird_left" if side < 0 else "bird_right",Vector3(side*0.106,0.20,0.025))
		Art._organic_link(leg,[Vector3.ZERO,Vector3(0,-0.085,-0.015),Vector3(0,-0.170,0.020)],[Vector2(0.026,0.029),Vector2(0.019,0.020),Vector2(0.021,0.024)],"9f793d","leg")
		Art._animal_form(leg,[Vector4(0.067,0.190,0.008,0.007),Vector4(0.095,0.150,0.014,0.010),Vector4(0.070,0.085,0.013,0.009),Vector4(0.023,0.012,0.017,0.013)],-0.177,"ab8443","webbed_foot")
		for toe: int in range(3):
			var spread := float(toe-1)
			Art._organic_link(leg,[Vector3(spread*0.022,-0.164,0.066),Vector3(spread*0.058,-0.164,0.130),Vector3(spread*0.077,-0.176,0.195-absf(spread)*0.013)],[Vector2(0.009,0.008),Vector2(0.007,0.006),Vector2(0.004,0.003)],"99723a","toe")
		var wing := Art._node(raw,"left_wing" if side < 0 else "right_wing",Vector3(side*0.19,0.49,-0.02))
		Art._animal_form(wing,[Vector4(0.040,0.175,0.040,0.060),Vector4(0.085,0.065,0.073,0.100),Vector4(0.095,-0.105,0.055,0.120),Vector4(0.058,-0.285,0.026,0.074),Vector4(0.012,-0.390,0.008,0.012)],0,"82775a","wing")
		for feather: int in range(4):
			var x: float = side*(0.012+float(feather)*0.019)
			Art._organic_link(wing,[Vector3(x,0.059-float(feather)*0.010,-0.015),Vector3(x*0.82,0.036-float(feather)*0.010,-0.158),Vector3(x*0.48,0.005-float(feather)*0.010,-0.307)],[Vector2(0.009,0.005),Vector2(0.008,0.004),Vector2(0.003,0.002)],"665f47","feather")
	var tail := Art._node(raw,"tail",Vector3(0,0.40,-0.33))
	Art._animal_form(tail,[Vector4(0.130,0.0,0.050,0.040),Vector4(0.140,-0.100,0.035,0.025),Vector4(0.100,-0.260,0.020,0.015),Vector4(0.015,-0.310,0.008,0.006)],0,"9b906b","tail_feathers")
