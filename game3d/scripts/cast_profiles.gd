class_name RockBottomCastProfiles
extends RefCounted
## Authored source identities, not a random-avatar generator. No AI or simulation.
## Raw geometry is consumed once by the roster's resource/skin template cache.

const Art = preload("res://scripts/character_art.gd")
const Content = preload("res://scripts/content_catalog.gd")
const HUMAN_ACTIONS: Array[StringName] = [&"talk",&"eat",&"inspect",&"windup",&"strike",&"grab",&"throw",&"sleep",&"read",&"write",&"phone",&"strum",&"fold",&"serve",&"seated",&"radio",&"taser"]
static var _surface_materials: Dictionary = {}
const BASE_NAMES := {
	"TRE BAG TONY":"tony","YURI":"yuri","BRUTUS":"brutus","PAWN SHOP PETE":"pete","LURCH":"lurch","THE POSSUM":"possum",
	"SPIDER-BITE SHERRI":"sherri","PAULIE THE FACE":"paulie","CHATTY DAVE":"dave","WHOLE FOODS MOM":"mom","FATHER O'MALLEY":"priest",
	"THE CONDUCTOR":"conductor","LOUD LARRY":"larry","STRIPE":"stripe","THE PIGEON KING":"pigeon","THE BIG GUY":"biggu","CUBSCOUT":"cubscout",
	"JOGGER":"jogger","DOG WALKER (PAISLEY)":"dogwalker","BUSKER":"busker","HORSE COP":"horsecop","THE VAPE LORD":"vapelord",
	"A POTHOLE (TALKING)":"pothole","MAYOR'S COUSIN":"mayorscousin","THE PHONE GUY":"phoneguy","BAGGIE BARB":"barb","PINKY POLENTA":"pinky",
	"THE MATHEMATICIAN":"math","THE TRAIN HOPPER":"train_hopper","PARK BENCH PHILOSOPHER":"philosopher","THE LEASING GUY":"lease_guy",
	"GUTTER GREG":"gutter_greg","THE DOG":"scrap_dog","LAUNDROMAT LADY":"launderlady","METER MAID":"metermaid","FOOD TRUCK GUY":"foodtruck",
	"THE PRIEST'S SON":"priestson","KARAOKE MIKE":"karaoke","TARP KNIGHT":"blue_tarp_guard","CART LANCER":"receipt_guard","WIRE DEACON":"wire_guard"}

# Shape = height, hip, shoulder half-width, belly projection. Face = breadth,
# jaw breadth, nose projection, eyebrow slant. These are independent authored
# proportions; a palette substitution alone is never a character definition.
const HUMANS := {
	&"sherri":{"shape":Vector4(1.78,0.86,0.205,0.12),"arm":0.61,"face":Vector4(0.87,0.80,1.12,-0.018),"head_scale":Vector3(0.94,1.04,0.96),"hair":"spikes","hair_color":"3e2825","wear":"cropped","shirt":"57404c","pants":"3a282d","skin":"ad8055","accent":"9d8a60","action":&"phone"},
	&"paulie":{"shape":Vector4(1.78,0.72,0.28,0.18),"arm":0.52,"face":Vector4(1.42,1.40,0.80,0.004),"head_scale":Vector3(1.12,1.16,1.02),"hair":"slick","hair_color":"261f1b","wear":"open_jacket","shirt":"8a5050","pants":"604020","skin":"bd9b69","accent":"b19b67","action":&"talk"},
	&"dave":{"shape":Vector4(1.78,0.74,0.29,0.235),"arm":0.55,"face":Vector4(1.07,1.05,0.92,0.008),"head_scale":Vector3(1.0,0.96,1.0),"hair":"receding","hair_color":"604020","wear":"cardigan","shirt":"7c633f","pants":"67543b","skin":"ad8055","accent":"a7976e","action":&"sleep"},
	&"mom":{"shape":Vector4(1.80,0.86,0.255,0.17),"arm":0.56,"face":Vector4(0.97,0.88,0.95,0.008),"head_scale":Vector3(0.98,1.0,1.0),"hair":"bob","hair_color":"685237","wear":"zip_jacket","shirt":"6c724d","pants":"4a4a3c","skin":"bd9b69","accent":"a9996f","action":&"eat"},
	&"priest":{"shape":Vector4(1.87,0.81,0.28,0.19),"arm":0.59,"face":Vector4(1.00,1.06,1.06,0.0),"head_scale":Vector3(1,1,1),"hair":"receding","hair_color":"30261b","wear":"cassock","shirt":"292a25","pants":"24251f","skin":"bd9b69","accent":"b9ad7f","action":&"talk"},
	&"priest_fallen":{"shape":Vector4(1.87,0.81,0.28,0.19),"arm":0.59,"face":Vector4(1.00,1.06,1.06,-0.008),"head_scale":Vector3(1,1,1),"hair":"untidy","hair_color":"30261b","wear":"open_jacket","shirt":"554b35","pants":"292a25","skin":"bd9b69","accent":"b9ad7f","action":&"talk"},
	&"conductor":{"shape":Vector4(1.88,0.83,0.27,0.20),"arm":0.58,"face":Vector4(0.98,1.12,1.23,-0.006),"head_scale":Vector3(1,1.06,1),"hair":"cap","hair_color":"504c36","wear":"uniform","shirt":"625b3f","pants":"302d24","skin":"ad8055","accent":"b5a067","action":&"read"},
	&"larry":{"shape":Vector4(1.98,0.80,0.355,0.25),"arm":0.66,"face":Vector4(1.19,1.23,1.00,-0.022),"head_scale":Vector3(1.04,1.03,1.02),"hair":"buzz","hair_color":"8b7951","wear":"workshirt","shirt":"794c37","pants":"3b3026","skin":"ad8055","accent":"a68752","action":&"talk"},
	&"stripe":{"shape":Vector4(1.83,0.85,0.255,0.18),"arm":0.59,"face":Vector4(0.96,0.95,1.10,-0.014),"head_scale":Vector3(1,1,1),"hair":"hood","hair_color":"5b5940","wear":"hoodie","shirt":"625940","pants":"3b3229","skin":"ad8055","accent":"b3a068","action":&"serve"},
	&"biggu":{"shape":Vector4(2.23,0.95,0.43,0.32),"arm":0.77,"face":Vector4(1.26,1.30,0.94,0.006),"head_scale":Vector3(1.12,1.1,1.07),"hair":"buzz","hair_color":"625236","wear":"workshirt","shirt":"6b5e3f","pants":"5e513a","skin":"ad8055","accent":"a98e5b","action":&"talk"},
	&"cubscout":{"shape":Vector4(1.28,0.52,0.185,0.13),"arm":0.37,"face":Vector4(1.08,0.85,0.64,0.010),"head_scale":Vector3(0.83,0.82,0.85),"hair":"cap","hair_color":"5c613b","wear":"shorts","shirt":"8c7950","pants":"3e3c2a","skin":"bd9b69","accent":"b6a366","action":&"serve"},
	&"jogger":{"shape":Vector4(1.91,0.97,0.245,0.14),"arm":0.60,"face":Vector4(0.91,0.91,1.13,-0.005),"head_scale":Vector3(0.96,1.04,0.98),"hair":"headband","hair_color":"706044","wear":"sports","shirt":"8a6242","pants":"3f3d2e","skin":"bd9b69","accent":"b9ad7f","action":&"inspect"},
	&"dogwalker":{"shape":Vector4(1.83,0.85,0.25,0.18),"arm":0.60,"face":Vector4(0.97,1.04,0.91,0.010),"head_scale":Vector3(1,1.02,1),"hair":"bob","hair_color":"51473a","wear":"raincoat","shirt":"96654a","pants":"3f3e32","skin":"bd9b69","accent":"8f8865","action":&"talk"},
	&"busker":{"shape":Vector4(1.86,0.86,0.235,0.15),"arm":0.62,"face":Vector4(0.91,0.91,1.21,0.010),"head_scale":Vector3(0.98,1.05,1),"hair":"long","hair_color":"67553b","wear":"open_jacket","shirt":"7f6540","pants":"514b38","skin":"ad8055","accent":"b29859","action":&"strum"},
	&"vapelord":{"shape":Vector4(1.89,0.82,0.32,0.245),"arm":0.60,"face":Vector4(1.11,1.08,0.94,-0.010),"head_scale":Vector3(1.04,1,1),"hair":"hood","hair_color":"4e4c3b","wear":"hoodie","shirt":"4a4b34","pants":"302f27","skin":"ad8055","accent":"8f8865","action":&"talk"},
	&"mayorscousin":{"shape":Vector4(1.92,0.87,0.31,0.225),"arm":0.59,"face":Vector4(1.09,1.18,1.08,0.015),"head_scale":Vector3(1.04,1.0,1),"hair":"slick","hair_color":"30261b","wear":"no_pants","shirt":"6b5b42","pants":"ad8055","skin":"ad8055","accent":"b0a173","action":&"phone"},
	&"phoneguy":{"shape":Vector4(1.89,0.93,0.215,0.13),"arm":0.65,"face":Vector4(0.90,0.80,1.25,-0.003),"head_scale":Vector3(0.96,1.08,1),"hair":"quiff","hair_color":"6c5736","wear":"zip_jacket","shirt":"484b36","pants":"5d553b","skin":"ad8055","accent":"9e946e","action":&"phone"},
	&"barb":{"shape":Vector4(1.69,0.67,0.33,0.26),"arm":0.50,"face":Vector4(1.11,1.10,1.00,-0.008),"head_scale":Vector3(1.03,0.96,1),"hair":"bun","hair_color":"63533d","wear":"cardigan","shirt":"776240","pants":"504835","skin":"ad8055","accent":"aa9872","action":&"read"},
	&"pinky":{"shape":Vector4(1.83,0.91,0.215,0.13),"arm":0.63,"face":Vector4(0.88,0.90,1.17,0.012),"head_scale":Vector3(0.97,1.09,1),"hair":"braids","hair_color":"66492e","wear":"open_jacket","shirt":"8b6846","pants":"514332","skin":"ad8055","accent":"ad9361","action":&"serve"},
	&"math":{"shape":Vector4(1.87,0.86,0.22,0.14),"arm":0.60,"face":Vector4(0.93,0.96,1.28,0.0),"head_scale":Vector3(0.98,1.10,1),"hair":"receding","hair_color":"5e4730","wear":"cardigan","shirt":"696347","pants":"484433","skin":"ad8055","accent":"b5a578","action":&"write"},
	&"train_hopper":{"shape":Vector4(1.88,0.89,0.23,0.14),"arm":0.67,"face":Vector4(0.93,0.96,1.17,-0.006),"head_scale":Vector3(0.98,1.07,1),"hair":"beanie","hair_color":"71694f","wear":"open_jacket","shirt":"62614c","pants":"544d3b","skin":"ad8055","accent":"9b9272","action":&"sleep"},
	&"philosopher":{"shape":Vector4(1.65,0.67,0.30,0.225),"arm":0.51,"face":Vector4(1.01,0.93,1.20,0.014),"head_scale":Vector3(1.03,1,1),"hair":"brim","hair_color":"64563e","wear":"long_coat","shirt":"695337","pants":"4b4333","skin":"bd9b69","accent":"a59b7d","action":&"serve"},
	&"lease_guy":{"shape":Vector4(1.84,0.76,0.32,0.255),"arm":0.56,"face":Vector4(1.08,1.17,1.09,0.0),"head_scale":Vector3(1,1,1),"hair":"cap","hair_color":"695234","wear":"workshirt","shirt":"826347","pants":"3c382a","skin":"bd9b69","accent":"b5a578","action":&"write"},
	&"gutter_greg":{"shape":Vector4(1.82,0.85,0.22,0.14),"arm":0.67,"face":Vector4(0.90,0.86,1.24,-0.010),"head_scale":Vector3(0.97,1.09,1),"hair":"beanie","hair_color":"605037","wear":"raincoat","shirt":"725a3c","pants":"414336","skin":"ad8055","accent":"ba9d42","action":&"inspect"},
	&"launderlady":{"shape":Vector4(1.72,0.69,0.335,0.27),"arm":0.52,"face":Vector4(1.13,1.08,0.99,0.005),"head_scale":Vector3(1.02,0.98,1),"hair":"bun","hair_color":"5b5243","wear":"dress","shirt":"8e6750","pants":"393b2f","skin":"bd9b69","accent":"afa17a","action":&"fold"},
	&"metermaid":{"shape":Vector4(1.77,0.80,0.28,0.185),"arm":0.54,"face":Vector4(1.00,1.14,1.06,-0.018),"head_scale":Vector3(1,1,1),"hair":"cap","hair_color":"49483a","wear":"uniform","shirt":"696a4a","pants":"373a2f","skin":"bd9b69","accent":"b5a46d","action":&"write"},
	&"foodtruck":{"shape":Vector4(1.86,0.73,0.355,0.29),"arm":0.54,"face":Vector4(1.18,1.18,0.92,-0.005),"head_scale":Vector3(1.07,1,1),"hair":"cap","hair_color":"8c7a50","wear":"apron","shirt":"6e6248","pants":"514b37","skin":"ad8055","accent":"b8ab7c","action":&"serve"},
	&"priestson":{"shape":Vector4(1.74,0.82,0.22,0.14),"arm":0.56,"face":Vector4(0.97,1.03,1.06,0.0),"head_scale":Vector3(0.96,0.97,0.98),"hair":"backward_cap","hair_color":"716344","wear":"zip_jacket","shirt":"464732","pants":"303329","skin":"bd9b69","accent":"b9ad7f","action":&"inspect"},
	&"karaoke":{"shape":Vector4(1.82,0.78,0.28,0.21),"arm":0.57,"face":Vector4(1.04,1.11,1.09,0.014),"head_scale":Vector3(1.02,1,1),"hair":"quiff","hair_color":"6b5133","wear":"open_jacket","shirt":"7b583e","pants":"493629","skin":"ad8055","accent":"b1a073","action":&"talk"},
	&"blue_tarp_guard":{"shape":Vector4(1.91,0.81,0.33,0.23),"arm":0.61,"face":Vector4(1.04,1.13,1.09,-0.012),"head_scale":Vector3(1.02,1.02,1),"hair":"tarp_hood","hair_color":"34434a","wear":"tarp","shirt":"34434a","pants":"3b3329","skin":"ad8055","accent":"ad994b","action":&"windup"},
	&"receipt_guard":{"shape":Vector4(1.94,0.86,0.29,0.19),"arm":0.64,"face":Vector4(1.00,1.07,1.18,-0.010),"head_scale":Vector3(1,1.07,1),"hair":"cap","hair_color":"9b9272","wear":"workshirt","shirt":"60563e","pants":"41392c","skin":"ad8055","accent":"b7aa7d","action":&"windup"},
	&"wire_guard":{"shape":Vector4(1.99,0.95,0.235,0.145),"arm":0.70,"face":Vector4(0.91,1.0,1.27,-0.012),"head_scale":Vector3(1,1.10,1),"hair":"untidy","hair_color":"3a3025","wear":"long_coat","shirt":"5c513b","pants":"403a2b","skin":"ad8055","accent":"a27744","action":&"inspect"},
	&"mounted_rider":{"shape":Vector4(1.83,0.82,0.30,0.22),"arm":0.58,"face":Vector4(1.07,1.12,1.08,-0.008),"head_scale":Vector3(1,1,1),"hair":"cap","hair_color":"39414a","wear":"uniform","shirt":"414b58","pants":"2d323a","skin":"bd9b69","accent":"b49d5b","action":&"seated"}}
const B2_HUMANS := {
	&"cop":{"shape":Vector4(1.91,0.78,0.35,0.285),"arm":0.59,"face":Vector4(1.15,1.21,1.02,-0.014),"head_scale":Vector3(1.06,1.0,1.03),"hair":"cap","hair_color":"2d3a4b","wear":"uniform","shirt":"39495c","pants":"29323c","skin":"bd9b69","accent":"b6a160","action":&"radio"},
	&"brendan":{"shape":Vector4(1.86,0.90,0.235,0.15),"arm":0.60,"face":Vector4(0.92,0.88,1.12,0.016),"head_scale":Vector3(1.0,1.04,0.98),"hair":"cap","hair_color":"33465d","wear":"uniform","shirt":"43566b","pants":"303b48","skin":"bd9b69","accent":"b6a160","action":&"taser"},
	&"price_guy":{"shape":Vector4(2.01,0.91,0.27,0.17),"arm":0.64,"face":Vector4(0.94,0.96,1.05,0.0),"head_scale":Vector3(0.99,1.03,1.0),"hair":"brim","hair_color":"25251f","wear":"long_coat","shirt":"282a23","pants":"24271f","skin":"ad8055","accent":"a89c72","action":&"","still":true},
	&"bus_driver":{"shape":Vector4(1.92,0.85,0.30,0.22),"arm":0.60,"face":Vector4(1.03,1.17,1.18,-0.007),"head_scale":Vector3(1.0,1.08,1.0),"hair":"cap","hair_color":"454d3c","wear":"uniform","shirt":"59604a","pants":"373f31","skin":"ad8055","accent":"b6aa7b","action":&"serve","still":true},
	&"day3_visitor":{"shape":Vector4(2.04,0.98,0.22,0.145),"arm":0.72,"face":Vector4(0.88,0.87,1.21,0.003),"head_scale":Vector3(0.96,1.13,1.0),"hair":"slick","hair_color":"3b342a","wear":"long_coat","shirt":"474236","pants":"39382d","skin":"ad8055","accent":"81785b","action":&"talk","still":true},
	&"darryl_under_blue":{"shape":Vector4(2.10,0.87,0.43,0.31),"arm":0.66,"face":Vector4(1.19,1.27,1.04,-0.015),"head_scale":Vector3(1.08,1.05,1.05),"hair":"tarp_hood","hair_color":"34424a","wear":"tarp","shirt":"34424a","pants":"44382c","skin":"ad8055","accent":"b29d54","action":&"windup"},
	&"general_receipt":{"shape":Vector4(2.05,0.87,0.36,0.27),"arm":0.64,"face":Vector4(1.12,1.22,1.16,-0.012),"head_scale":Vector3(1.04,1.04,1.02),"hair":"slick","hair_color":"5c4d33","wear":"uniform","shirt":"6d5c40","pants":"4b4131","skin":"ad8055","accent":"c2b587","action":&"read"},
	&"bishop_wire":{"shape":Vector4(2.17,1.0,0.26,0.17),"arm":0.75,"face":Vector4(0.92,1.02,1.29,-0.013),"head_scale":Vector3(1.01,1.14,1.02),"hair":"receding","hair_color":"62523b","wear":"long_coat","shirt":"62583f","pants":"423d2d","skin":"ad8055","accent":"ad824d","action":&"inspect"},
	&"curb_emperor":{"shape":Vector4(2.08,0.86,0.39,0.29),"arm":0.64,"face":Vector4(1.19,1.23,1.00,-0.019),"head_scale":Vector3(1.08,1.05,1.04),"hair":"slick","hair_color":"423222","wear":"open_jacket","shirt":"725137","pants":"473829","skin":"ad8055","accent":"b5a56f","action":&"talk"}}
const B2_NAMES := {
	"COP":["cop","cop"],"COUSIN BRENDAN":["brendan","brendan"],"THE PRICE GUY":["price_guy","price_guy"],
	"THE BUS DRIVER":["lurch","bus_driver"],"SOMEONE YOU DON'T KNOW":["lurch","day3_visitor"],
	"OLD SCHOOL BRUTUS":["os_brutus","os_brutus"],"BRUTUS THE OLDER":["brutus","brutus_older"],"YOUR POSSUM":["possum","possum"],
	"DARRYL UNDER BLUE":["darryl_under_blue","darryl_under_blue"],"GENERAL RECEIPT":["general_receipt","general_receipt"],
	"BISHOP WIRE":["bishop_wire","bishop_wire"],"THE CURB EMPEROR":["curb_emperor","curb_emperor"]}
const PRETENDER_UNIFORMS := {&"pretender_tarp":&"blue_tarp_guard",&"pretender_receipt":&"receipt_guard",&"pretender_wire":&"wire_guard"}
static var _pretender_pattern: RegEx


static func visual_for_actor(actor: Dictionary) -> StringName:
	if not actor.get("name") is String or not actor.get("sprite") is String: return &""
	var name_text: String = actor.name
	var sprite: String = actor.sprite
	var content := Content.load_content()
	var aliases: Dictionary = content.get("actors",{}).get("aliases",{})
	if aliases.has(name_text): name_text = String(aliases[name_text])
	if B2_NAMES.has(name_text):
		var mapping: Array = B2_NAMES[name_text]
		return StringName(mapping[1]) if sprite == mapping[0] else &""
	if _pretender_pattern == null:
		_pretender_pattern = RegEx.new()
		var source_pattern := ""
		for family: Dictionary in content.get("actors",{}).get("generatedFamilies",[]):
			if family.get("canonical","") == "CURB PRETENDER No. N": source_pattern = String(family.get("pattern",""))
		if source_pattern.is_empty() or _pretender_pattern.compile(source_pattern) != OK:
			_pretender_pattern = null
			return &""
	if _pretender_pattern.search(name_text) != null:
		for visual: StringName in PRETENDER_UNIFORMS:
			if String(PRETENDER_UNIFORMS[visual]) == sprite: return visual
		return &""
	if name_text == "KNIGHT EMERITUS":
		return StringName(sprite) if sprite in ["blue_tarp_guard","receipt_guard","wire_guard"] else &""
	if not BASE_NAMES.has(name_text) or BASE_NAMES[name_text] != sprite: return &""
	if sprite == "priest" and (actor.get("isOmalleyFallen",false) == true or actor.get("id","") == "omalley_fallen"): return &"priest_fallen"
	return StringName(sprite)


static func supported_visuals(packet: String = "all") -> PackedStringArray:
	var result := PackedStringArray()
	if packet in ["all","b1"]:
		for id: StringName in HUMANS: result.append(String(id))
		result.append_array(PackedStringArray(["scrap_dog","paisley","pigeon","horsecop","pothole"]))
	if packet in ["all","b2"]:
		for id: StringName in B2_HUMANS: result.append(String(id))
		for id: StringName in PRETENDER_UNIFORMS: result.append(String(id))
		result.append_array(PackedStringArray(["os_brutus","brutus_older"]))
	return result


static func definition(id: StringName) -> Dictionary:
	if HUMANS.has(id) or B2_HUMANS.has(id) or PRETENDER_UNIFORMS.has(id):
		var p: Dictionary
		if HUMANS.has(id): p = HUMANS[id].duplicate(true)
		elif B2_HUMANS.has(id): p = B2_HUMANS[id].duplicate(true)
		else:
			p = HUMANS[PRETENDER_UNIFORMS[id]].duplicate(true)
			p["uniform_visual"] = PRETENDER_UNIFORMS[id]
			p["action"] = &"read"
		var shape: Vector4 = p.shape
		p.merge({"family":"human","height":shape.x,"hip":shape.y,"leg":shape.y-0.12,"stride":(shape.y-0.12)*1.58,"visual_id":id,"actions":HUMAN_ACTIONS.duplicate(),"forward":Vector3.BACK})
		if id == &"dogwalker": p["companions"] = [{"visual_id":&"paisley","position":Vector3(0.66,0,0.13),"bone":"root","follow_bone":false,"action":&""}]
		if id in [&"philosopher",&"receipt_guard",&"pretender_receipt",&"bishop_wire"]: p["death_pose"] = {"right_elbow":Vector3.ZERO}
		if id == &"launderlady": p["death_props"] = {"laundry_basket":Transform3D(Basis.IDENTITY,Vector3(-0.58,0.135,0.85))}
		if id == &"mounted_rider": p["base_pose"] = {"left_hip":Vector3(-0.86,0,-0.25),"right_hip":Vector3(-0.86,0,0.25),"left_knee":Vector3(1.28,0,0),"right_knee":Vector3(1.28,0,0),"left_ankle":Vector3(-0.25,0,0),"right_ankle":Vector3(-0.25,0,0),"left_shoulder":Vector3(-0.42,0,0),"right_shoulder":Vector3(-0.42,0,0),"left_elbow":Vector3(-0.68,0,0),"right_elbow":Vector3(-0.68,0,0)}
		return p
	match id:
		&"scrap_dog": return {"family":"quadruped","height":0.88,"hip":0.42,"leg":0.32,"stride":0.78,"visual_id":id,"actions":[&"windup",&"lunge",&"bite"],"forward":Vector3.BACK}
		&"paisley": return {"family":"quadruped","height":0.52,"hip":0.22,"leg":0.15,"stride":0.40,"death_lift":0.24,"visual_id":id,"actions":[&"windup",&"lunge",&"bite"],"forward":Vector3.BACK}
		&"pigeon": return {"family":"bird","height":0.63,"hip":0.12,"leg":0.10,"stride":0.23,"visual_id":id,"actions":[&"talk",&"eat",&"windup",&"bite"],"forward":Vector3.BACK}
		&"horsecop": return {"family":"mounted","height":3.05,"hip":1.00,"leg":0.88,"stride":1.60,"visual_id":id,"actions":[&"talk",&"windup",&"lunge",&"bite"],"forward":Vector3.BACK,"companions":[{"visual_id":&"mounted_rider","position":Vector3(0,0.64,-0.10),"bone":"chest","action":&"seated"}]}
		&"pothole": return {"family":"object","height":0.065,"hip":0.02,"leg":0.01,"stride":1.0,"visual_id":id,"actions":[&"talk"],"forward":Vector3.BACK}
		&"os_brutus",&"brutus_older":
			var size := 1.5 if id == &"brutus_older" else 1.25
			return {"family":"quadruped","height":0.95*size,"hip":0.43*size,"leg":0.34*size,"stride":0.72*size,"visual_id":id,"actions":[&"windup",&"lunge",&"bite"],"forward":Vector3.BACK,"source_scale_baked":size}
	return {}


static func build_raw(id: StringName) -> Node3D:
	var p := definition(id)
	if p.is_empty(): return null
	var raw := Node3D.new()
	raw.name = String(id)
	raw.set_meta("height",p.height)
	raw.set_meta("roster_attachments",[])
	raw.set_meta("signature",String(id))
	if p.family == "human": _human(raw,p)
	else:
		match id:
			&"scrap_dog": _dog(raw,false)
			&"paisley": _dog(raw,true)
			&"pigeon": _pigeon(raw)
			&"horsecop": _horse(raw)
			&"pothole": _pothole(raw)
			&"os_brutus",&"brutus_older": _brutus_variant(raw,id)
	_surface_types(raw,p.family)
	return raw


static func _surface_types(node: Node, family: String) -> void:
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		var source := part.material_override as StandardMaterial3D
		var label := String(part.name)
		var color := source.albedo_color.to_html(false)
		var kind := ""
		if color not in [Art.SKIN,Art.SKIN_PALE,Art.SKIN_SHADE] and label in ["shirt","upper_sleeve","fore_sleeve","cuff","trousers","shorts","jacket","pocket","pocket_seam","sash","hood","hood_roof","tarp_poncho","apron","apron_pocket","cap","knit_cap","headband","pillow","backpack","bedroll","bag","folded_shirt","emperor_middlecoat","emperor_outercoat","chair_seat","chair_back"]: kind = "fabric"
		elif label in ["shoe","sole","hoof"]: kind = "rubber"
		elif label in ["rim","shield","coil","wire_stole","cart_fork","tine","blade","key","tooth","stirrup","ring","hook_shaft","hook_end"]: kind = "painted_metal"
		elif label in ["guitar_body","cane_shaft","cane_handle"]: kind = "wood"
		elif label == "curb_block": kind = "concrete"
		elif family in ["quadruped","mounted"] and label in ["body","head_shape","long_head","muzzle","skull","old_muzzle","lower_jaw","leg","ear","tail_fur","tail_hair","fur_lock","mane"]: kind = "skin"
		if not kind.is_empty():
			var key := kind+":"+color
			if not _surface_materials.has(key):
				var material := Art.Surfaces.material(kind,color).duplicate() as StandardMaterial3D
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.uv1_world_triplanar = false
				_surface_materials[key] = material
			part.material_override = _surface_materials[key]
	for child: Node in node.get_children(): _surface_types(child,family)


static func _human(raw: Node3D, p: Dictionary) -> void:
	var shape: Vector4 = p.shape
	var width: float = shape.z
	var depth: float = shape.w
	var hip: float = p.hip
	var head_scale: Vector3 = p.head_scale
	var top: float = float(p.height)-0.24*head_scale.y
	var shoulder: float = top-0.30*head_scale.y
	var waist: float = hip+0.08
	var belly: float = lerpf(waist,shoulder,0.36)
	var leg_width: float = clampf(width*0.43,0.085,0.17)
	var arm_width: float = clampf(width*0.40,0.075,0.155)
	var leg_color: String = p.skin if p.wear in ["shorts","sports","no_pants"] else p.pants
	for side: float in [-1.0,1.0]:
		var leg := Art._leg(raw,side,hip,p.leg,leg_width,leg_color,"49402f")
		leg.position.x = side*maxf(leg_width*1.2,width*0.46)
		if p.wear in ["shorts","sports"]:
			Art._garment(leg,[Vector4(leg_width*1.16,-float(p.leg)*0.43,0.13,0.13),Vector4(leg_width*1.2,0.035,0.14,0.13)],p.pants,"shorts")
		if p.visual_id == &"mom":
			for toe: int in range(5): Art._oval(leg,Vector3(side*0.04+float(toe-2)*0.027,-float(p.leg)-0.057,0.213),Vector3(0.017,0.023,0.03),"4c4937","shoe_toe")
		var arm := Art._arm(raw,side,Vector3(side*width,shoulder,0),p.arm,arm_width,p.shirt,p.skin)
		arm.rotation.z = side*(0.025 if p.wear != "tarp" else 0.09)
		if p.visual_id in [&"sherri",&"phoneguy"] and side > 0:
			arm.rotation.x = -0.42
			(arm.get_node("forearm") as Node3D).rotation.x = -0.95
		if p.visual_id == &"jogger":
			arm.rotation.x = -0.12 if side < 0 else 0.12
			(arm.get_node("forearm") as Node3D).rotation.x = -1.10
	var hem := hip-0.07
	if p.wear in ["cassock","long_coat","dress","raincoat"]: hem = hip*0.40
	Art._garment(raw,[Vector4(width*0.89,hem,depth*0.76,depth*0.70),Vector4(width*0.99,waist,depth*0.91,depth*0.78),Vector4(width*1.03,belly,depth,depth*0.86),Vector4(width,shoulder-0.07,depth*0.86,depth*0.77),Vector4(width*0.84,shoulder+0.045,depth*0.69,depth*0.65),Vector4(0.08,shoulder+0.11,0.075,0.08)],p.shirt,"shirt")
	Art._taper(raw,Vector3(0,top-0.225,0),0.17,Vector2(0.073,0.068),Vector2(0.085,0.077),p.skin)
	var head := _face(raw,Vector3(0,top,0.025),p)
	head.scale = head_scale
	_hair(head,p)
	_clothing(raw,p,shoulder,waist,depth,width)
	_signatures(raw,p,head,shoulder,waist)
	_b2_signatures(raw,p,head,shoulder,waist)


static func _face(raw: Node3D, at: Vector3, p: Dictionary) -> Node3D:
	var head := Art._node(raw,"head",at)
	var f: Vector4 = p.face
	var rings: Array[PackedVector3Array] = [Art._face_ring(0.045,-0.215,0.055,0.06),Art._face_ring(0.120*f.y,-0.188,0.12,0.115),Art._face_ring(0.154*f.x,-0.13,0.146,0.139),Art._face_ring(0.172*f.x,-0.07,0.150,0.16,0.005),Art._face_ring(0.174*f.x,-0.042,0.154,0.165,0.062*f.z),Art._face_ring(0.177*f.x,0.013,0.155,0.169,0.042*f.z,-0.004),Art._face_ring(0.178*f.x,0.047,0.155,0.168,0.025*f.z,-0.010),Art._face_ring(0.175*f.x,0.10,0.164,0.164),Art._face_ring(0.168*f.x,0.153,0.15,0.151),Art._face_ring(0.141*f.x,0.196,0.128,0.130),Art._face_ring(0.082*f.x,0.220,0.076,0.080),Art._face_ring(0.009,0.231,0.01,0.012)]
	Art._instance(head,Art._sculpt_mesh(rings,0.76),Vector3.ZERO,p.skin,"face")
	for side: float in [-1.0,1.0]:
		var x: float = side*0.081*f.x
		var eye_y := 0.041+(0.004 if side < 0 else 0.0)
		Art._panel(head,PackedVector3Array([Vector3(side*0.168*f.x,0.03,0.012),Vector3(side*0.20*f.x,0.047,0.005),Vector3(side*0.218*f.x,0.014,0.0),Vector3(side*0.205*f.x,-0.065,0.006),Vector3(side*0.172*f.x,-0.057,0.023)]),p.skin,"ear")
		Art._panel(head,PackedVector3Array([Vector3(side*0.185*f.x,0.015,0.019),Vector3(side*0.203*f.x,0.004,0.014),Vector3(side*0.195*f.x,-0.041,0.017),Vector3(side*0.182*f.x,-0.036,0.023)]),Art.SKIN_SHADE,"ear_fold")
		if p.visual_id == &"dave":
			Art._panel(head,PackedVector3Array([Vector3(x-0.038,eye_y,0.157),Vector3(x,eye_y-0.004,0.163),Vector3(x+0.036,eye_y,0.157),Vector3(x+0.033,eye_y-0.007,0.158),Vector3(x,eye_y-0.010,0.164),Vector3(x-0.035,eye_y-0.006,0.158)]),"513d2d","closed_eye")
		else:
			Art._panel(head,PackedVector3Array([Vector3(x-0.038,eye_y,0.157),Vector3(x-0.018,eye_y+0.013,0.163),Vector3(x+0.023,eye_y+0.011,0.163),Vector3(x+0.038,eye_y-0.001,0.155),Vector3(x+0.018,eye_y-0.012,0.163),Vector3(x-0.017,eye_y-0.011,0.163)]),Art.CREAM,"eye")
			Art._panel(head,PackedVector3Array([Vector3(x-0.010,eye_y+0.011,0.168),Vector3(x+0.010,eye_y+0.011,0.168),Vector3(x+0.010,eye_y-0.011,0.168),Vector3(x-0.010,eye_y-0.011,0.168)]),"514a2d","iris")
			Art._box(head,Vector3(x,eye_y,0.170),Vector3(0.008,0.020,0.002),Art.DARK,"pupil")
			Art._panel(head,PackedVector3Array([Vector3(x-0.038,eye_y+0.002,0.158),Vector3(x-0.018,eye_y+0.013,0.165),Vector3(x+0.023,eye_y+0.011,0.165),Vector3(x+0.039,eye_y-0.001,0.156),Vector3(x+0.026,eye_y+0.022,0.160),Vector3(x-0.020,eye_y+0.025,0.160)]),p.skin,"upper_lid")
		Art._panel(head,PackedVector3Array([Vector3(side*0.041*f.x,0.079+f.w,0.169),Vector3(side*0.127*f.x,0.078-f.w,0.152),Vector3(side*0.133*f.x,0.090-f.w,0.151),Vector3(side*0.045*f.x,0.096+f.w,0.169)]),p.hair_color,"brow")
	var mouth_width := 0.060*f.y
	if p.visual_id == &"larry":
		Art._panel(head,PackedVector3Array([Vector3(-0.067,-0.092,0.155),Vector3(0.058,-0.090,0.158),Vector3(0.068,-0.152,0.154),Vector3(0.030,-0.177,0.146),Vector3(-0.040,-0.173,0.147),Vector3(-0.073,-0.146,0.152)]),Art.DARK,"yell")
		Art._box(head,Vector3(0,-0.103,0.162),Vector3(0.089,0.014,0.004),"b9ac7f","teeth")
	else:
		Art._panel(head,PackedVector3Array([Vector3(-mouth_width,-0.120,0.153),Vector3(0,-0.125,0.159),Vector3(mouth_width,-0.118,0.153),Vector3(mouth_width*0.9,-0.124,0.154),Vector3(0,-0.131,0.160),Vector3(-mouth_width*0.92,-0.126,0.154)]),"60412e","mouth")
	return head


static func _hair(head: Node3D, p: Dictionary) -> void:
	var id: StringName = p.get("uniform_visual",p.visual_id)
	var kind: String = p.hair
	var color: String = p.hair_color
	var f: Vector4 = p.face
	var hair := Art._node(head,"hair_style",Vector3.ZERO)
	hair.scale.x = f.x
	if kind in ["hood","tarp_hood"]:
		Art._coat_shell(hair,-0.11,0.27,Vector2(0.222,0.225),Vector2(0.207,0.21),color,"hood")
		Art._garment(hair,[Vector4(0.103,0.267,0.132,0.132),Vector4(0.075,0.284,0.095,0.095),Vector4(0.025,0.296,0.035,0.035)],color,"hood_roof",[],0.35)
		return
	Art._hair_cap(hair,"tony" if kind == "receding" else "lurch",color)
	if kind in ["cap","backward_cap","brim","beanie","headband"]:
		if kind == "headband":
			Art._garment(hair,[Vector4(0.179,0.12,0.162,0.163),Vector4(0.170,0.154,0.155,0.155)],p.accent,"headband")
		elif kind == "beanie":
			Art._garment(hair,[Vector4(0.189,0.10,0.175,0.17),Vector4(0.188,0.15,0.174,0.169),Vector4(0.161,0.229,0.143,0.145),Vector4(0.06,0.261,0.058,0.060)],color,"knit_cap")
		else:
			Art._garment(hair,[Vector4(0.188,0.12,0.174,0.17),Vector4(0.19,0.18,0.175,0.171),Vector4(0.158,0.24,0.147,0.144)],color,"cap")
			var peak := Art._oval(hair,Vector3(0,0.126,-0.10 if kind == "backward_cap" else 0.10),Vector3(0.238 if kind == "brim" else 0.204,0.018,0.25 if kind == "brim" else 0.19),color,"peak")
			if kind == "backward_cap": peak.rotation.z = 0.06
	elif kind in ["bob","long","braids"]:
		for side: float in [-1.0,1.0]:
			var bottom := -0.16 if kind == "bob" else -0.37
			if kind == "braids":
				Art._organic_link(hair,[Vector3(side*0.17,0.15,-0.02),Vector3(side*0.18,-0.04,0.02),Vector3(side*0.19,-0.20,0.03),Vector3(side*0.22,bottom,0.07)],[Vector2(0.047,0.052),Vector2(0.038,0.042),Vector2(0.030,0.035),Vector2(0.018,0.024)],color,"braid")
				Art._box(hair,Vector3(side*0.22,bottom+0.025,0.07),Vector3(0.052,0.025,0.047),p.accent,"hair_tie")
			else:
				Art._garment(hair,[Vector4(0.05,bottom,0.09,0.08),Vector4(0.061,-0.03,0.13,0.12),Vector4(0.052,0.15,0.12,0.11)],color,"side_hair").position.x = side*0.165
	elif kind == "bun":
		Art._oval(hair,Vector3(0,0.14,-0.19),Vector3(0.105,0.112,0.088),color,"bun")
	elif kind in ["spikes","quiff","untidy"]:
		for strand: int in range(5 if kind == "spikes" else 3):
			var x := (float(strand)-2.0)*0.060
			var start := Vector3(x,0.17,0.04)
			var tip := Vector3(x+(0.025 if kind == "quiff" else -0.02),0.27+0.035*sin(float(strand)*1.8),0.11 if kind == "quiff" else 0.0)
			Art._organic_link(hair,[start,(start+tip)*0.5,tip],[Vector2(0.055,0.065),Vector2(0.038,0.045),Vector2(0.003,0.006)],color,"hair_peak")
	if id in [&"train_hopper",&"gutter_greg",&"wire_guard",&"bishop_wire"]:
		var beard_color := "9b9272" if id in [&"train_hopper",&"bishop_wire"] else color
		Art._garment(hair,[Vector4(0.045,-0.30,0.09,0.04),Vector4(0.125,-0.19,0.159,0.08),Vector4(0.15,-0.10,0.155,0.09)],beard_color,"beard")


static func _clothing(raw: Node3D, p: Dictionary, shoulder: float, waist: float, depth: float, width: float) -> void:
	var id: StringName = p.get("uniform_visual",p.visual_id)
	var wear: String = p.wear
	if wear in ["open_jacket","cardigan","no_pants"]:
		Art._coat_shell(raw,float(p.hip)-0.11,shoulder+0.10,Vector2(width*1.02,width*1.02),Vector2(depth+0.028,depth*0.85+0.026),p.shirt,"jacket")
		for side: float in [-1.0,1.0]: Art._lapel(raw,side,shoulder-0.07,depth*0.84+0.035,width*0.80,p.accent)
	if wear == "tarp":
		Art._garment(raw,[Vector4(width*1.29,float(p.hip)-0.20,depth+0.08,depth+0.06),Vector4(width*1.20,waist,depth+0.06,depth+0.05),Vector4(width*1.17,shoulder-0.02,depth*0.87+0.07,depth*0.82+0.07),Vector4(0.13,shoulder+0.20,0.13,0.13)],p.shirt,"tarp_poncho",[],0.35)
		for side: float in [-1.0,1.0]: Art._oval(raw,Vector3(side*width*0.95,shoulder-0.04,depth*0.87+0.076),Vector3(0.017,0.017,0.004),p.accent,"grommet")
	if wear == "apron":
		_cloth_sheet(raw,[Vector3(width*0.76,float(p.hip)-0.09,depth*0.84+0.045),Vector3(width*0.84,waist+0.18,depth+0.046),Vector3(width*0.67,shoulder-0.15,depth+0.043),Vector3(width*0.52,shoulder-0.04,depth*0.90+0.046)],p.accent,"apron")
		Art._box(raw,Vector3(0,waist+0.13,depth+0.048),Vector3(width,0.13,0.012),"807653","apron_pocket")
	if wear in ["cassock","uniform","zip_jacket","workshirt","dress","hoodie","raincoat"]:
		Art._box(raw,Vector3(0,(shoulder+waist)*0.5,depth+0.012),Vector3(0.014,shoulder-waist,0.011),"3e382a","front_seam")
		for button: int in range(3):
			var y := lerpf(waist+0.06,shoulder-0.07,float(button)/2.0)
			Art._oval(raw,Vector3(0,y,depth+0.02),Vector3(0.009,0.011,0.006),p.accent,"button")
	if wear not in ["tarp","apron","sports","shorts"]:
		for side: float in [-1.0,1.0]:
			Art._box(raw,Vector3(side*width*0.60,waist+0.05,depth*0.89+0.025),Vector3(width*0.38,0.115,0.016),p.shirt,"pocket")
			Art._box(raw,Vector3(side*width*0.60,waist+0.108,depth*0.89+0.035),Vector3(width*0.39,0.012,0.014),p.accent,"pocket_seam")
	if id in [&"priest",&"priestson"]:
		Art._box(raw,Vector3(0,shoulder+0.079,0.084),Vector3(0.087,0.037,0.027),Art.CREAM,"collar")
	if id == &"priest":
		Art._box(raw,Vector3(0,shoulder-0.20,depth+0.03),Vector3(0.018,0.14,0.012),p.accent,"cross_vertical")
		Art._box(raw,Vector3(0,shoulder-0.17,depth+0.032),Vector3(0.092,0.018,0.013),p.accent,"cross_horizontal")
	if id in [&"stripe",&"cubscout",&"receipt_guard"]:
		Art._panel(raw,PackedVector3Array([Vector3(-width*0.80,shoulder,depth*0.82+0.05),Vector3(-width*0.50,shoulder+0.02,depth*0.88+0.05),Vector3(width*0.87,float(p.hip),depth*0.90+0.05),Vector3(width*0.62,float(p.hip)-0.025,depth*0.90+0.05)]),p.accent,"sash")
		if id == &"receipt_guard":
			var paper := Art._panel(raw,PackedVector3Array([Vector3(width*0.62,float(p.hip),depth+0.03),Vector3(width*0.89,float(p.hip),depth+0.03),Vector3(width*0.96,0.24,depth+0.10),Vector3(width*0.69,0.20,depth+0.09)]),p.accent,"receipt_tail")
			paper.set_meta("signature","long receipt")
	if id in [&"metermaid",&"mounted_rider",&"cop",&"brendan"]:
		Art._panel(raw,PackedVector3Array([Vector3(-width*0.55,shoulder-0.10,depth+0.018),Vector3(-width*0.32,shoulder-0.10,depth+0.018),Vector3(-width*0.31,shoulder-0.16,depth+0.020),Vector3(-width*0.43,shoulder-0.20,depth+0.021),Vector3(-width*0.56,shoulder-0.16,depth+0.020)]),p.accent,"badge")


static func _held(raw: Node3D, p: Dictionary, side: String, label: String, offset: Vector3 = Vector3.ZERO) -> Node3D:
	var forearm := raw.get_node(side+"_arm/forearm") as Node3D
	var sign_value := -1.0 if side == "left" else 1.0
	var prop := Art._node(forearm,label,Vector3(sign_value*0.01,-float(p.arm)*0.47-0.07,0.07)+offset)
	var attachments: Array = raw.get_meta("roster_attachments")
	attachments.append({"path":NodePath(side+"_arm/forearm/"+label),"bone":side+"_wrist"})
	return prop


static func _chest_prop(raw: Node3D, label: String, at: Vector3) -> Node3D:
	var prop := Art._node(raw,label,at)
	var attachments: Array = raw.get_meta("roster_attachments")
	attachments.append({"path":NodePath(label),"bone":"chest"})
	return prop


static func _cloth_sheet(raw: Node3D, rows: Array[Vector3], color: String, label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows.size()-1):
		for column: int in range(4):
			var a := float(column)/2.0-1.0
			var b := float(column+1)/2.0-1.0
			var low: Vector3 = rows[row]
			var high: Vector3 = rows[row+1]
			var aa := Vector3(a*low.x,low.y,low.z-a*a*0.012)
			var ab := Vector3(b*low.x,low.y,low.z-b*b*0.012)
			var ba := Vector3(a*high.x,high.y,high.z-a*a*0.012)
			var bb := Vector3(b*high.x,high.y,high.z-b*b*0.012)
			Art._triangle(surface,aa,ab,ba)
			Art._triangle(surface,ab,bb,ba)
	Art._instance(raw,surface.commit(),Vector3.ZERO,color,label)


static func _board(parent: Node3D, size: Vector2, color: String, label: String = "board") -> void:
	Art._box(parent,Vector3.ZERO,Vector3(size.x,size.y,0.025),color,label)
	for line: int in range(4): Art._box(parent,Vector3(-size.x*0.08,size.y*(0.27-float(line)*0.16),0.015),Vector3(size.x*(0.62 if line != 2 else 0.40),0.009,0.003),"5d5740","line")


static func _phone(parent: Node3D) -> void:
	Art._box(parent,Vector3.ZERO,Vector3(0.075,0.145,0.022),"38382d","phone")
	Art._box(parent,Vector3(0,0.01,0.013),Vector3(0.057,0.104,0.004),"767c61","screen")
	Art._box(parent,Vector3(0,0.042,0.016),Vector3(0.042,0.008,0.003),"b1aa7c","screen_line")


static func _glasses(head: Node3D, width: float, low: bool = false) -> void:
	var y := 0.012 if low else 0.048
	for side: float in [-1.0,1.0]:
		for vertical: float in [-1.0,1.0]: Art._box(head,Vector3(side*0.081*width,y+vertical*0.034,0.18),Vector3(0.116,0.008,0.008),"504734","spectacle_rim")
		for horizontal: float in [-1.0,1.0]: Art._box(head,Vector3(side*0.081*width+horizontal*0.054,y,0.18),Vector3(0.008,0.068,0.008),"504734","spectacle_rim")
	Art._box(head,Vector3(0,y+0.008,0.183),Vector3(0.053,0.008,0.009),"504734","bridge")


static func _ring(parent: Node3D, at: Vector3, radius: float, thickness: float, color: String, label: String, basis: Basis = Basis.IDENTITY) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(16):
		var a := TAU*float(segment)/16.0
		var b := TAU*float(segment+1)/16.0
		for side: int in range(6):
			var c := TAU*float(side)/6.0
			var d := TAU*float(side+1)/6.0
			var aa := Vector3(cos(a)*(radius+cos(c)*thickness),sin(a)*(radius+cos(c)*thickness),sin(c)*thickness)
			var ab := Vector3(cos(b)*(radius+cos(c)*thickness),sin(b)*(radius+cos(c)*thickness),sin(c)*thickness)
			var ba := Vector3(cos(a)*(radius+cos(d)*thickness),sin(a)*(radius+cos(d)*thickness),sin(d)*thickness)
			var bb := Vector3(cos(b)*(radius+cos(d)*thickness),sin(b)*(radius+cos(d)*thickness),sin(d)*thickness)
			Art._triangle(surface,at+basis*aa,at+basis*ab,at+basis*ba)
			Art._triangle(surface,at+basis*ab,at+basis*bb,at+basis*ba)
	Art._instance(parent,surface.commit(),Vector3.ZERO,color,label)


static func _signatures(raw: Node3D, p: Dictionary, head: Node3D, shoulder: float, waist: float) -> void:
	var id: StringName = p.get("uniform_visual",p.visual_id)
	var depth: float = p.shape.w
	var width: float = p.shape.z
	match id:
		&"sherri",&"phoneguy":
			_phone(_held(raw,p,"right","phone"))
			if id == &"phoneguy":
				Art._box(raw,Vector3(width*0.85,waist,depth*0.6),Vector3(0.08,0.14,0.04),p.accent,"power_bank")
				Art._between(raw,Vector3(width*0.85,waist+0.07,depth*0.6),Vector3(width+0.04,shoulder-0.20,0.15),0.004,0.004,"302d23","cable")
		&"paulie":
			for side: float in [-1.0,1.0]: Art._panel(head,PackedVector3Array([Vector3(side*0.18,-0.08,0.145),Vector3(side*0.205,-0.10,0.107),Vector3(side*0.19,-0.113,0.129)]),Art.SKIN_SHADE,"cheek_crease")
		&"dave":
			var pillow := _held(raw,p,"left","pillow")
			Art._oval(pillow,Vector3(0,0.05,0),Vector3(0.16,0.22,0.065),"a3926a","pillow")
			Art._box(raw,Vector3(-width*0.65,waist-0.01,depth*0.87+0.04),Vector3(0.10,0.12,0.026),"453622","wallet")
		&"mom":
			var bottle := _held(raw,p,"right","kombucha")
			Art._taper(bottle,Vector3(0,0.07,0),0.21,Vector2(0.038,0.038),Vector2(0.032,0.032),"6c7047")
			Art._taper(bottle,Vector3(0,0.196,0),0.058,Vector2(0.019,0.019),Vector2(0.019,0.019),"514e37")
			Art._box(bottle,Vector3(0,0.07,0.038),Vector3(0.057,0.085,0.005),"b8aa7b","label")
			_bag(_held(raw,p,"left","tote"),Vector3(0.22,0.26,0.11),"a1936c")
		&"priest_fallen":
			Art._box(raw,Vector3(-width*0.6,waist+0.12,depth+0.04),Vector3(0.087,0.037,0.024),Art.CREAM,"pocket_collar")
		&"conductor":
			_board(_held(raw,p,"right","ticket_punch"),Vector2(0.08,0.13),"a39467")
			_board(_held(raw,p,"left","timetable"),Vector2(0.18,0.23),"b4a679")
		&"stripe":
			var soap := _held(raw,p,"right","soap_package")
			Art._box(soap,Vector3.ZERO,Vector3(0.13,0.08,0.07),"b4a77b","soap_box")
			Art._box(soap,Vector3(0,0,0.037),Vector3(0.07,0.026,0.004),"79673d","wrapper_mark")
		&"cubscout":
			_backpack(raw,shoulder,waist,0.19,"5d6240",true)
			var tin := _held(raw,p,"right","popcorn")
			Art._taper(tin,Vector3.ZERO,0.19,Vector2(0.065,0.065),Vector2(0.065,0.065),"a59353")
			Art._box(tin,Vector3(0,0,0.064),Vector3(0.05,0.065,0.006),"6b4f30","tin_label")
		&"jogger":
			var watch := _held(raw,p,"right","stopwatch",Vector3(0,0.12,0.0))
			Art._oval(watch,Vector3.ZERO,Vector3(0.036,0.043,0.015),"b0a276","watch")
			Art._box(watch,Vector3(0,0,0.017),Vector3(0.042,0.018,0.004),"4c4e36","digits")
		&"dogwalker":
			var leash := _held(raw,p,"right","leash_handle")
			_ring(leash,Vector3.ZERO,0.055,0.009,"4d4838","handle")
			Art._organic_link(raw,[Vector3(width+0.06,shoulder-float(p.arm)-0.10,0.08),Vector3(0.47,0.38,0.12),Vector3(0.66,0.34,0.31)],[Vector2(0.005,0.005),Vector2(0.005,0.005),Vector2(0.005,0.005)],"5c513d","leash")
		&"busker":
			var guitar := _chest_prop(raw,"guitar",Vector3(0.12,waist+0.06,depth+0.16))
			guitar.rotation.z = 0.95
			Art._garment(guitar,[Vector4(0.08,-0.23,0.052,0.044),Vector4(0.19,-0.13,0.065,0.055),Vector4(0.17,-0.02,0.061,0.051),Vector4(0.105,0.07,0.052,0.044),Vector4(0.145,0.15,0.055,0.045),Vector4(0.11,0.22,0.051,0.043)],"956a38","guitar_body")
			Art._oval(guitar,Vector3(0,0.03,0.062),Vector3(0.05,0.055,0.006),"382e21","sound_hole")
			Art._box(guitar,Vector3(0,0.40,0),Vector3(0.057,0.40,0.037),"4e3825","neck")
			for string_index: int in range(3): Art._between(guitar,Vector3(float(string_index-1)*0.009,-0.11,0.073),Vector3(float(string_index-1)*0.009,0.59,0.028),0.0017,0.0017,"b0a07b","string")
		&"vapelord":
			_backpack(raw,shoulder,waist,0.20,"4d4a35",false)
			var dragon := Art._node(raw,"backpack_dragon",Vector3(0,shoulder+0.03,-0.23))
			Art._animal_form(dragon,[Vector4(0.03,0.18,0.035,0.025),Vector4(0.065,0.07,0.065,0.05),Vector4(0.055,-0.07,0.05,0.04)],0,"78674c","dragon_head")
			for side: float in [-1.0,1.0]: Art._panel(dragon,PackedVector3Array([Vector3(side*0.05,0,-0.03),Vector3(side*0.27,0.16,-0.04),Vector3(side*0.21,-0.09,-0.01)]),"776045","wing")
			var device := _held(raw,p,"right","spectrum_device")
			Art._box(device,Vector3.ZERO,Vector3(0.06,0.17,0.036),"8b8060","abstract_device")
		&"mayorscousin":
			var bread := _held(raw,p,"right","bread_phone")
			Art._oval(bread,Vector3.ZERO,Vector3(0.046,0.11,0.035),"aa8950","bread")
			Art._oval(raw,Vector3(-width*0.55,shoulder-0.15,depth+0.035),Vector3(0.023,0.023,0.008),p.accent,"lapel_pin")
		&"barb":
			_glasses(head,p.face.x,true)
			var paper := _held(raw,p,"left","crossword",Vector3(0.12,0.04,0.08))
			_board(paper,Vector2(0.25,0.21),"b6a97c")
			for row: int in range(4):
				for column: int in range(4):
					if (row+column*2)%3 == 0: Art._box(paper,Vector3(-0.08+float(column)*0.047,-0.06+float(row)*0.04,0.02),Vector3(0.026,0.026,0.004),"53503c","crossword_square")
			_bag(_held(raw,p,"right","hard_purse"),Vector3(0.22,0.19,0.10),"5a4530")
		&"math":
			_glasses(head,p.face.x)
			var board := _chest_prop(raw,"equation_board",Vector3(-0.04,waist+0.16,depth+0.20))
			board.rotation.x = -0.95
			_board(board,Vector2(0.29,0.28),"b6a877")
			var pencil := _held(raw,p,"right","pencil")
			pencil.rotation.z = PI
			Art._between(pencil,Vector3(0,-0.06,0),Vector3(0,0.09,0),0.006,0.004,"a28a44","pencil")
		&"train_hopper":
			_backpack(raw,shoulder,waist,0.21,"62674a",true)
			_ring(raw,Vector3(width*0.78,waist,depth+0.035),0.045,0.008,"a39870","carabiner")
		&"philosopher":
			_glasses(head,p.face.x,true)
			var cane := _held(raw,p,"right","cane",Vector3(0,0.0,0.02))
			Art._between(cane,Vector3(0,0.07,0),Vector3(0.07,-0.61,0.05),0.016,0.012,"51402a","cane_shaft")
			Art._between(cane,Vector3(-0.06,0.07,0),Vector3(0.025,0.07,0),0.02,0.02,"51402a","cane_handle")
		&"lease_guy":
			_board(_held(raw,p,"right","clipboard"),Vector2(0.22,0.29),"ac9d71")
			var keys := _held(raw,p,"left","key_ring")
			_ring(keys,Vector3(0,-0.04,0),0.075,0.009,"a89864","ring")
			for key: int in range(4):
				var x := float(key-2)*0.033
				Art._box(keys,Vector3(x,-0.15,0),Vector3(0.013,0.15,0.009),"a89864","key")
				Art._box(keys,Vector3(x+0.018,-0.20,0),Vector3(0.034,0.012,0.01),"a89864","tooth")
		&"gutter_greg":
			var hook := _held(raw,p,"left","inventory_hook")
			Art._between(hook,Vector3(0,0.10,0),Vector3(-0.07,-0.52,0),0.012,0.012,"968761","hook_shaft")
			Art._between(hook,Vector3(-0.07,-0.52,0),Vector3(-0.15,-0.49,0),0.012,0.012,"968761","hook_end")
			var duck := _held(raw,p,"right","rubber_duck")
			Art._oval(duck,Vector3.ZERO,Vector3(0.09,0.065,0.12),"b99b3c","duck_body")
			Art._oval(duck,Vector3(0,0.07,0.06),Vector3(0.049,0.055,0.05),"b99b3c","duck_head")
			Art._box(duck,Vector3(0,0.058,0.112),Vector3(0.052,0.017,0.04),"9b6531","bill")
		&"launderlady":
			var basket := _chest_prop(raw,"laundry_basket",Vector3(0,waist+0.12,depth+0.21))
			Art._garment(basket,[Vector4(0.25,-0.12,0.14,0.14),Vector4(0.31,0.10,0.185,0.185)],"a79b76","basket")
			for y: float in [-0.06,0.01,0.08]: Art._box(basket,Vector3(0,y,0.18),Vector3(0.57,0.015,0.012),"5e5c45","weave")
			for x: float in [-0.22,-0.11,0.0,0.11,0.22]: Art._box(basket,Vector3(x,-0.005,0.185),Vector3(0.012,0.18,0.012),"5e5c45","weave")
			Art._oval(basket,Vector3(0,0.11,0),Vector3(0.26,0.06,0.15),"8c8164","folded_shirt")
		&"metermaid":
			_board(_held(raw,p,"right","ticket_book"),Vector2(0.16,0.23),"b5a878")
			var meter := _held(raw,p,"left","personal_meter")
			Art._between(meter,Vector3(0,0.18,0),Vector3(0,-0.63,0),0.021,0.025,"555748","post")
			Art._oval(meter,Vector3(0,0.22,0),Vector3(0.08,0.11,0.05),"8c8c69","meter")
			Art._box(meter,Vector3(0,0.24,0.047),Vector3(0.09,0.055,0.01),"424736","window")
		&"foodtruck":
			_board(_held(raw,p,"left","order_pad"),Vector2(0.13,0.18),"b5a878")
			var spatula := _held(raw,p,"right","spatula")
			Art._between(spatula,Vector3(0,-0.07,0),Vector3(0,0.22,0),0.011,0.008,"454539","handle")
			Art._box(spatula,Vector3(0,0.28,0),Vector3(0.082,0.13,0.009),"96967b","blade")
		&"priestson":
			var player := _held(raw,p,"right","cassette_player")
			Art._box(player,Vector3.ZERO,Vector3(0.12,0.10,0.04),"94866a","player")
			Art._box(player,Vector3(0,0.015,0.024),Vector3(0.08,0.038,0.005),"474636","window")
			Art._oval(head,Vector3(0.195,0.005,0.026),Vector3(0.014,0.022,0.011),"ac9e76","earbud")
		&"karaoke":
			var mic := _held(raw,p,"right","microphone")
			Art._between(mic,Vector3(0,-0.08,0),Vector3(0,0.08,0),0.018,0.017,"47483b","handle")
			Art._oval(mic,Vector3(0,0.105,0),Vector3(0.033,0.047,0.033),"939078","mesh")
			var machine := _held(raw,p,"left","karaoke_machine")
			Art._box(machine,Vector3(0,-0.08,0),Vector3(0.30,0.24,0.15),"625039","machine")
			Art._box(machine,Vector3(0,-0.03,0.08),Vector3(0.22,0.06,0.008),"ac9b68","display")
		&"blue_tarp_guard":
			var shield := _held(raw,p,"left","bucket_lid")
			Art._oval(shield,Vector3(0,-0.015,0.05),Vector3(0.23,0.23,0.027),"797b66","shield")
			_ring(shield,Vector3(0,-0.015,0.073),0.20,0.012,"98967a","rim")
		&"receipt_guard":
			var fork := _held(raw,p,"right","cart_fork")
			Art._between(fork,Vector3(0,-0.55,0),Vector3(0,0.35,0),0.017,0.017,"7d7d64","shaft")
			for side: float in [-1.0,1.0]: Art._between(fork,Vector3(0,0.25,0),Vector3(side*0.10,0.53,0),0.015,0.012,"7d7d64","tine")
		&"wire_guard":
			for row: int in range(4):
				_ring(raw,Vector3(0,waist+float(row)*0.11,0),width*1.05,0.010,"a07b4c","wire_stole",Basis(Vector3.RIGHT,PI*0.5))
			var coil := _held(raw,p,"left","wire_coil")
			for layer: int in range(3): _ring(coil,Vector3(0,0,float(layer)*0.018),0.15,0.012,"a07b4c","coil")


static func _b2_signatures(raw: Node3D, p: Dictionary, head: Node3D, shoulder: float, waist: float) -> void:
	var id: StringName = p.visual_id
	var width: float = p.shape.z
	var depth: float = p.shape.w
	match id:
		&"cop",&"brendan":
			var radio := _held(raw,p,"left","radio")
			Art._box(radio,Vector3.ZERO,Vector3(0.083,0.16 if id == &"cop" else 0.205,0.045),"343b38","radio_body")
			Art._between(radio,Vector3(-0.025,0.07,0),Vector3(-0.025,0.20,0),0.005,0.004,"343b38","antenna")
			for row: int in range(3): Art._box(radio,Vector3(0,0.025-float(row)*0.027,0.025),Vector3(0.053,0.008,0.005),"78826e","speaker")
			Art._box(raw,Vector3(0,waist-0.02,depth*0.90+0.025),Vector3(width*1.7,0.07,0.025),"2d3027","duty_belt")
			Art._box(raw,Vector3(0,waist-0.02,depth*0.90+0.042),Vector3(0.060,0.055,0.010),"9a8d5f","buckle")
			if id == &"cop":
				var cup := _held(raw,p,"right","coffee")
				Art._taper(cup,Vector3(0,0.04,0),0.13,Vector2(0.033,0.033),Vector2(0.043,0.043),"afa178")
				Art._taper(cup,Vector3(0,0.111,0),0.018,Vector2(0.046,0.046),Vector2(0.046,0.046),"5b5641")
				Art._between(raw,Vector3(width*0.87,waist-0.02,0.015),Vector3(width*0.93,waist-0.40,0.03),0.018,0.017,"33392d","baton")
				Art._panel(head,PackedVector3Array([Vector3(-0.072,-0.082,0.158),Vector3(0,-0.078,0.168),Vector3(0.073,-0.085,0.158),Vector3(0.060,-0.104,0.160),Vector3(0,-0.096,0.169),Vector3(-0.059,-0.101,0.160)]),"443323","moustache")
			else:
				var taser := _held(raw,p,"right","taser")
				taser.rotation.x = PI*0.5
				Art._box(taser,Vector3(0,0.045,0.015),Vector3(0.095,0.055,0.13),"a49b4d","device_body")
				Art._box(taser,Vector3(0,-0.025,0),Vector3(0.045,0.11,0.045),"3c4032","grip")
				Art._box(taser,Vector3(0,0.048,0.086),Vector3(0.074,0.037,0.012),"363b2f","device_face")
				Art._between(raw,Vector3(width*0.78,waist,0.03),Vector3(width*0.80,waist-0.15,0.03),0.025,0.018,"555c4a","flashlight")
		&"price_guy":
			Art._panel(raw,PackedVector3Array([Vector3(width*0.40,shoulder-0.30,depth+0.028),Vector3(width*0.72,shoulder-0.28,depth+0.025),Vector3(width*0.76,shoulder-0.41,depth+0.030),Vector3(width*0.43,shoulder-0.43,depth+0.033)]),"a99f78","price_tag")
			Art._between(raw,Vector3(width*0.55,shoulder-0.29,depth+0.031),Vector3(width*0.62,shoulder-0.15,depth*0.84+0.022),0.002,0.002,"a99f78","tag_string")
		&"bus_driver":
			var tickets := _held(raw,p,"right","ticket_roll")
			Art._organic_link(tickets,[Vector3(-0.05,0,0),Vector3(0.05,0,0)],[Vector2(0.045,0.045),Vector2(0.045,0.045)],"b6aa7b","roll")
			Art._box(tickets,Vector3(0,-0.085,0.047),Vector3(0.10,0.17,0.008),"b6aa7b","ticket_strip")
			_board(_held(raw,p,"left","route_sheet"),Vector2(0.17,0.23),"a99f77")
			Art._box(raw,Vector3(-width*0.48,shoulder-0.14,depth+0.019),Vector3(0.10,0.032,0.008),"b1a675","transit_patch")
			Art._panel(raw,PackedVector3Array([Vector3(-0.020,shoulder+0.03,0.09),Vector3(0.02,shoulder+0.03,0.09),Vector3(0.034,shoulder-0.22,depth+0.03),Vector3(0,shoulder-0.25,depth+0.031),Vector3(-0.028,shoulder-0.22,depth+0.03)]),"3b4131","tie")
		&"day3_visitor":
			Art._box(raw,Vector3(width*0.62,waist+0.02,depth+0.02),Vector3(0.09,0.12,0.013),"55513f","coat_repair")
		&"darryl_under_blue":
			var lid := _held(raw,p,"left","ruler_bucket_lid")
			Art._oval(lid,Vector3(0,0,0.04),Vector3(0.29,0.30,0.035),"7b7c66","shield")
			_ring(lid,Vector3(0,0,0.074),0.255,0.015,"a09b76","rim")
			for side: float in [-1.0,1.0]:
				Art._between(raw,Vector3(side*width,shoulder-0.12,depth+0.075),Vector3(side*width*0.96,waist-0.10,depth+0.076),0.009,0.009,"72807a","tarp_seam")
		&"general_receipt":
			_paper_crown(head,"c1b486",0.10)
			for side: float in [-1.0,1.0]: Art._box(raw,Vector3(side*width*0.83,shoulder+0.02,0.01),Vector3(0.23,0.07,0.23),p.accent,"epaulette")
			_cloth_sheet(raw,[Vector3(0.15,0.28,depth*0.84+0.04),Vector3(0.17,waist+0.15,depth+0.045),Vector3(0.15,shoulder-0.03,depth*0.90+0.04)],p.accent,"receipt_bib")
			for mark: int in range(7):
				var y := 0.43+float(mark)*0.125
				var z := lerpf(depth*0.84+0.04,depth+0.045,clampf((y-0.28)/(waist-0.13),0,1)) if y <= waist+0.15 else lerpf(depth+0.045,depth*0.90+0.04,clampf((y-waist-0.15)/(shoulder-waist-0.18),0,1))
				Art._box(raw,Vector3(0,y,z+0.004),Vector3(0.17 if mark%2 == 0 else 0.11,0.014,0.005),"6c654b","receipt_line")
			var scroll := _held(raw,p,"left","receipt_scroll")
			_board(scroll,Vector2(0.18,0.52),"bdb085")
			for y: float in [-0.27,0.27]: Art._organic_link(scroll,[Vector3(-0.11,y,0),Vector3(0.11,y,0)],[Vector2(0.027,0.027),Vector2(0.027,0.027)],"bdb085","scroll_roll")
		&"bishop_wire":
			var mitre := Art._node(head,"antenna_mitre",Vector3.ZERO)
			for side: float in [-1.0,1.0]:
				Art._between(mitre,Vector3(side*0.15,0.18,0),Vector3(0,0.49,0),0.012,0.010,p.accent,"mitre_antenna")
				Art._between(mitre,Vector3(side*0.15,0.18,0),Vector3(-side*0.14,0.18,0),0.010,0.010,p.accent,"mitre_base")
			_ring(mitre,Vector3(0,0.42,0.004),0.04,0.008,"b6a565","antenna_loop")
			for row: int in range(5): _ring(raw,Vector3(0,waist+float(row)*0.10,0),width*1.05,0.010,p.accent,"wire_stole",Basis(Vector3.RIGHT,PI*0.5))
			var crozier := _held(raw,p,"right","antenna_crozier")
			Art._between(crozier,Vector3(0,-0.72,0),Vector3(0,0.73,0),0.016,0.015,p.accent,"staff")
			_ring(crozier,Vector3(0.065,0.78,0),0.10,0.014,p.accent,"crook")
			Art._between(crozier,Vector3(0.065,0.88,0),Vector3(0.065,1.02,0),0.008,0.006,p.accent,"antenna_tip")
		&"curb_emperor":
			Art._coat_shell(raw,0.48,shoulder+0.10,Vector2(width*1.03,width*1.02),Vector2(depth+0.045,depth*0.90+0.04),"92713f","emperor_middlecoat")
			Art._coat_shell(raw,0.35,shoulder+0.11,Vector2(width*1.13,width*1.10),Vector2(depth+0.085,depth*0.90+0.08),"60462e","emperor_outercoat")
			var crown := Art._node(head,"curb_crown",Vector3.ZERO)
			for stone: int in range(7):
				var angle := TAU*float(stone)/7.0
				var curb := Art._box(crown,Vector3(sin(angle)*0.15,0.245+0.024*float(stone%2),cos(angle)*0.13),Vector3(0.095,0.085+0.035*float(stone%2),0.072),"878166" if stone%2 == 0 else "706e58","curb_block")
				curb.rotation.y = angle
			var ruler := _held(raw,p,"right","broken_ruler")
			Art._panel(ruler,PackedVector3Array([Vector3(-0.025,-0.08,0),Vector3(0.025,-0.08,0),Vector3(0.025,0.23,0),Vector3(0.005,0.20,0),Vector3(-0.004,0.25,0),Vector3(-0.025,0.22,0)]),"b69d5f","ruler")
			for mark: int in range(7): Art._box(ruler,Vector3(-0.011,-0.05+float(mark)*0.035,0.003),Vector3(0.025 if mark%2 == 0 else 0.014,0.003,0.003),"655234","ruler_mark")
			_folding_chair(raw)
	if PRETENDER_UNIFORMS.has(id):
		_paper_crown(head,"b7aa7c",0.055)
		var side := "left" if id == &"pretender_receipt" else "right"
		_board(_held(raw,p,side,"petition"),Vector2(0.20,0.27),"b7aa7c")


static func _paper_crown(head: Node3D, color: String, point_height: float) -> void:
	var crown := Art._node(head,"paper_crown",Vector3.ZERO)
	var rings: Array[PackedVector3Array] = []
	for row: int in range(2):
		var ring := PackedVector3Array()
		for point: int in range(16):
			var angle := TAU*float(point)/16.0
			var y := 0.17 if row == 0 else 0.25+(point_height if point%2 == 0 else 0.0)
			ring.append(Vector3(sin(angle)*0.185,y,cos(angle)*0.17))
		rings.append(ring)
	Art._instance(crown,Art._sculpt_mesh(rings,0.15,false),Vector3.ZERO,color,"paper")


static func _folding_chair(raw: Node3D) -> void:
	var chair := Art._node(raw,"folding_chair",Vector3(0,0,-0.28))
	Art._box(chair,Vector3(0,0.48,-0.02),Vector3(0.62,0.04,0.45),"8b8258","chair_seat")
	Art._box(chair,Vector3(0,0.82,-0.20),Vector3(0.61,0.32,0.035),"8b8258","chair_back")
	for side: float in [-1.0,1.0]:
		Art._between(chair,Vector3(side*0.33,0.035,0.20),Vector3(side*0.33,0.99,-0.22),0.017,0.017,"85866a","chair_frame")
		Art._between(chair,Vector3(side*0.33,0.035,-0.27),Vector3(side*0.33,0.57,0.20),0.017,0.017,"85866a","chair_frame")
	var attachments: Array = raw.get_meta("roster_attachments")
	attachments.append({"path":NodePath("folding_chair"),"bone":"root"})


static func _bag(parent: Node3D, size: Vector3, color: String) -> void:
	Art._garment(parent,[Vector4(size.x*0.43,-size.y,size.z*0.45,size.z*0.45),Vector4(size.x*0.5,-size.y*0.2,size.z*0.5,size.z*0.5),Vector4(size.x*0.47,0,size.z*0.43,size.z*0.43)],color,"bag")
	_ring(parent,Vector3(0,0.015,0),size.x*0.31,0.008,"65563e","bag_handle")


static func _backpack(raw: Node3D, shoulder: float, waist: float, width: float, color: String, roll: bool) -> void:
	Art._oval(raw,Vector3(0,(shoulder+waist)*0.5,-0.23),Vector3(width,(shoulder-waist)*0.63,0.13),color,"backpack")
	if roll: Art._organic_link(raw,[Vector3(-width-0.03,shoulder-0.05,-0.24),Vector3(0,shoulder-0.05,-0.24),Vector3(width+0.03,shoulder-0.05,-0.24)],[Vector2(0.073,0.073),Vector2(0.075,0.075),Vector2(0.073,0.073)],"81775b","bedroll")
	for side: float in [-1.0,1.0]: Art._between(raw,Vector3(side*width*0.7,shoulder,0.07),Vector3(side*width*0.8,waist,0.19),0.015,0.015,"504b36","pack_strap")


static func _dog(raw: Node3D, fluffy: bool) -> void:
	var h := 0.22 if fluffy else 0.42
	var length := 0.15 if fluffy else 0.32
	var coat := "8d7c5b" if fluffy else "76654b"
	var width := 0.19 if fluffy else 0.205
	var body_y := h+0.035
	Art._animal_form(raw,[Vector4(width*0.70,0.28,0.16,0.12),Vector4(width,0.12,0.21,0.17),Vector4(width*0.94,-0.12,0.19,0.14),Vector4(width*0.64,-0.34,0.14,0.10),Vector4(0.035,-0.41,0.04,0.035)],body_y,coat,"body")
	var head := Art._node(raw,"head",Vector3(0,h+0.14,0.28))
	Art._animal_form(head,[Vector4(0.045,0.24,0.035,0.03),Vector4(0.085,0.16,0.07,0.06),Vector4(0.15,0.02,0.15,0.12),Vector4(0.125,-0.09,0.12,0.10),Vector4(0.04,-0.14,0.04,0.04)],0,coat,"head_shape")
	Art._oval(head,Vector3(0,-0.025,0.245),Vector3(0.043,0.027,0.024),"343025","nose")
	for side: float in [-1.0,1.0]:
		Art._panel(head,PackedVector3Array([Vector3(side*0.075,0.035,0.119),Vector3(side*0.11,0.045,0.086),Vector3(side*0.115,0.020,0.088),Vector3(side*0.08,0.014,0.12)]),"2f2b21","eye")
		Art._organic_link(head,[Vector3(side*0.13,0.07,-0.02),Vector3(side*0.16,0.01,-0.015),Vector3(side*0.14,-0.13,0.025)],[Vector2(0.058,0.04),Vector2(0.066,0.04),Vector2(0.028,0.023)],"65573f","ear")
		for z: float in [-0.26,0.19]:
			var limb := Art._node(raw,("front_" if z > 0 else "back_")+("left" if side < 0 else "right"),Vector3(side*width*0.72,h,z))
			Art._organic_link(limb,[Vector3.ZERO,Vector3(side*0.02,-length*0.5,0.0),Vector3(side*0.03,-length,0.03)],[Vector2(0.043,0.046),Vector2(0.032,0.035),Vector2(0.028,0.035)],coat,"leg")
			Art._oval(limb,Vector3(side*0.03,-length-0.035,0.075),Vector3(0.06,0.041,0.08),"a1906b","paw")
	var tail := Art._node(raw,"tail",Vector3(0,h+0.04,-0.34))
	Art._organic_link(tail,[Vector3.ZERO,Vector3(0.05,0.06,-0.19),Vector3(0.12,0.13,-0.30)],[Vector2(0.042,0.045),Vector2(0.032,0.034),Vector2(0.012,0.014)],coat,"tail_fur")
	if fluffy:
		for tuft: int in range(11):
			var angle := TAU*float(tuft)/11.0
			var x := sin(angle)*0.16
			var z := cos(angle)*0.27-0.04
			Art._organic_link(raw,[Vector3(x,0.32,z),Vector3(x*1.2,0.19,z*1.1),Vector3(x*1.27,0.09,z*1.12)],[Vector2(0.075,0.075),Vector2(0.066,0.064),Vector2(0.018,0.024)],"9b8a65" if tuft%3 == 0 else coat,"fur_lock")
	else:
		Art._panel(raw,PackedVector3Array([Vector3(-0.14,body_y+0.145,0.02),Vector3(0.01,body_y+0.20,0.04),Vector3(0.16,body_y+0.12,-0.10),Vector3(0.05,body_y+0.18,-0.24),Vector3(-0.14,body_y+0.12,-0.20)]),"514a35","matted_patch")
		_ring(raw,Vector3(0,h+0.04,0.265),0.158,0.014,"67543a","rope_collar")
		_ring(raw,Vector3(0,h-0.10,0.28),0.035,0.008,"8f8561","broken_link")


static func _brutus_variant(raw: Node3D, id: StringName) -> void:
	Art._brutus(raw)
	var older: bool = id == &"brutus_older"
	var size := 1.5 if older else 1.25
	var palette := {"65432b":"804631" if older else "5e3926","704e34":"8c4c34" if older else "69432b","493222":"61372c" if older else "493025","9d8b68":"ac956d" if older else "8e7654","a29675":"b09c78" if older else "96845e","b2ae8c":"9e775a" if older else "a69974","30291d":"763c30" if older else "30291d"}
	_rescale_anatomy(raw,size,palette)
	# Geometry and pivot distances are scaled once before skin construction. The
	# actor root stays identity; source scale must not be applied a second time.
	raw.set_meta("height",0.95*size)
	var collar := Art._node(raw,"old_collar_detail",Vector3(0,0.43*size,0.47*size))
	Art._box(collar,Vector3.ZERO,Vector3(0.09,0.045,0.012),"927b48","collar_plate")
	if older:
		for side: float in [-1.0,1.0]: Art._between(raw,Vector3(side*0.19,0.95,0.08),Vector3(side*0.25,0.78,0.18),0.008,0.006,"b0966c","old_scar")


static func _rescale_anatomy(node: Node3D, factor: float, palette: Dictionary) -> void:
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var part := child as Node3D
		part.position *= factor
		if part is MeshInstance3D:
			part.scale *= factor
			var mesh := part as MeshInstance3D
			var color := (mesh.material_override as StandardMaterial3D).albedo_color.to_html(false)
			if palette.has(color): mesh.material_override = Art._mat(palette[color])
		_rescale_anatomy(part,factor,palette)


static func _pigeon(raw: Node3D) -> void:
	Art._animal_form(raw,[Vector4(0.075,0.20,0.13,0.12),Vector4(0.16,0.05,0.22,0.16),Vector4(0.14,-0.17,0.15,0.10),Vector4(0.035,-0.36,0.045,0.032)],0.27,"6b6d60","body")
	Art._garment(raw,[Vector4(0.07,0.31,0.08,0.08),Vector4(0.077,0.46,0.075,0.08)],"4f5844","neck")
	var head := Art._node(raw,"head",Vector3(0,0.52,0.10))
	Art._animal_form(head,[Vector4(0.065,0.11,0.068,0.064),Vector4(0.092,0.025,0.09,0.085),Vector4(0.070,-0.07,0.067,0.068)],0,"727364","head_shape")
	Art._animal_form(head,[Vector4(0.006,0.23,0.005,0.005),Vector4(0.033,0.12,0.025,0.021)],-0.014,"9b8e62","beak")
	for side: float in [-1.0,1.0]:
		Art._panel(head,PackedVector3Array([Vector3(side*0.058,0.023,0.084),Vector3(side*0.077,0.032,0.056),Vector3(side*0.084,0.016,0.049),Vector3(side*0.066,0.004,0.078)]),"ae9951","unblinking_eye")
		Art._oval(head,Vector3(side*0.071,0.017,0.072),Vector3(0.008,0.011,0.005),"25251f","pupil")
		var wing := Art._node(raw,"left_wing" if side < 0 else "right_wing",Vector3(side*0.13,0.36,-0.02))
		Art._panel(wing,PackedVector3Array([Vector3(0,0.03,0.11),Vector3(side*0.045,0.02,-0.06),Vector3(side*0.06,-0.085,-0.28),Vector3(side*0.02,-0.15,-0.19),Vector3(0,-0.08,0.11)]),"53584e","wing")
		for stripe: int in range(3): Art._between(wing,Vector3(side*0.015,-0.015-float(stripe)*0.025,-0.06),Vector3(side*0.04,-0.08-float(stripe)*0.018,-0.21),0.005,0.004,"343c32","feather")
	var leg := Art._node(raw,"single_leg",Vector3(-0.035,0.14,0.02))
	Art._between(leg,Vector3.ZERO,Vector3(0,-0.09,0.02),0.014,0.011,"927052","leg")
	for toe: int in range(3): Art._between(leg,Vector3(0,-0.09,0.02),Vector3(float(toe-1)*0.047,-0.115,0.095),0.009,0.004,"927052","toe")
	var stump := Art._node(raw,"missing_foot",Vector3(0.05,0.17,0.01))
	Art._organic_link(stump,[Vector3.ZERO,Vector3(0,-0.025,-0.01),Vector3(0,-0.038,-0.025)],[Vector2(0.022,0.025),Vector2(0.016,0.019),Vector2(0.009,0.012)],"877154","stump")
	var tail := Art._node(raw,"tail",Vector3(0,0.23,-0.24))
	Art._panel(tail,PackedVector3Array([Vector3(-0.07,0.02,0),Vector3(0.07,0.02,0),Vector3(0.11,-0.01,-0.19),Vector3(-0.09,-0.01,-0.21)]),"484f46","tail_feathers")


static func _horse(raw: Node3D) -> void:
	Art._animal_form(raw,[Vector4(0.24,0.48,0.34,0.28),Vector4(0.33,0.27,0.40,0.31),Vector4(0.34,-0.24,0.35,0.29),Vector4(0.28,-0.63,0.31,0.26),Vector4(0.11,-0.82,0.17,0.14)],1.04,"776045","body")
	Art._organic_link(raw,[Vector3(0,1.15,0.36),Vector3(0,1.42,0.44),Vector3(0,1.70,0.51)],[Vector2(0.24,0.27),Vector2(0.18,0.21),Vector2(0.13,0.16)],"7f684b","neck")
	var head := Art._node(raw,"head",Vector3(0,1.75,0.53))
	Art._animal_form(head,[Vector4(0.10,0.42,0.075,0.08),Vector4(0.12,0.27,0.10,0.11),Vector4(0.14,0.06,0.20,0.15),Vector4(0.12,-0.10,0.17,0.13)],0,"856e50","long_head",[-0.20,-0.13,0,0.015])
	Art._animal_form(head,[Vector4(0.10,0.45,0.06,0.055),Vector4(0.11,0.39,0.07,0.065)],-0.20,"544b3c","muzzle")
	for side: float in [-1.0,1.0]:
		Art._organic_link(head,[Vector3(side*0.09,0.14,-0.055),Vector3(side*0.105,0.27,-0.08),Vector3(side*0.095,0.32,-0.06)],[Vector2(0.035,0.039),Vector2(0.027,0.027),Vector2(0.006,0.009)],"6a523b","ear")
		Art._panel(head,PackedVector3Array([Vector3(side*0.10,0.062,0.14),Vector3(side*0.129,0.076,0.06),Vector3(side*0.137,0.050,0.03),Vector3(side*0.111,0.035,0.13)]),"2e2b21","eye")
		for z: float in [-0.59,0.34]:
			var leg := Art._node(raw,("front_" if z > 0 else "back_")+("left" if side < 0 else "right"),Vector3(side*0.215,1.0,z))
			Art._organic_link(leg,[Vector3.ZERO,Vector3(side*0.015,-0.36,-0.025),Vector3(side*0.02,-0.49,0.01),Vector3(side*0.03,-0.88,0.035)],[Vector2(0.11,0.13),Vector2(0.075,0.085),Vector2(0.065,0.075),Vector2(0.055,0.07)],"7f684b","leg")
			Art._garment(leg,[Vector4(0.08,-0.99,0.12,0.06),Vector4(0.073,-0.88,0.09,0.06)],"37352c","hoof").position.x = side*0.03
	var tail := Art._node(raw,"tail",Vector3(0,1.22,-0.72))
	Art._organic_link(tail,[Vector3.ZERO,Vector3(0.02,-0.24,-0.10),Vector3(0.08,-0.66,-0.14),Vector3(0.12,-0.96,-0.09)],[Vector2(0.07,0.08),Vector2(0.085,0.075),Vector2(0.066,0.045),Vector2(0.018,0.025)],"3f3326","tail_hair")
	Art._garment(raw,[Vector4(0.34,1.29,0.34,0.38),Vector4(0.30,1.38,0.28,0.34)],"493b2a","saddle")
	for side: float in [-1.0,1.0]:
		Art._between(raw,Vector3(side*0.26,1.35,-0.02),Vector3(side*0.39,0.89,-0.03),0.018,0.018,"51422e","stirrup_strap")
		_ring(raw,Vector3(side*0.39,0.85,-0.03),0.07,0.012,"938769","stirrup")
	Art._organic_link(raw,[Vector3(0,1.55,0.36),Vector3(0,1.30,0.30),Vector3(0,1.20,0.13)],[Vector2(0.045,0.06),Vector2(0.04,0.055),Vector2(0.035,0.035)],"403326","mane")


static func _pothole(raw: Node3D) -> void:
	var head := Art._node(raw,"head",Vector3(0,0.025,0))
	Art._oval(head,Vector3.ZERO,Vector3(0.53,0.022,0.39),"28291f","broken_rim")
	Art._oval(head,Vector3(0,0.012,0.01),Vector3(0.44,0.015,0.30),"14170f","hole")
	for chip: int in range(9):
		var angle := TAU*float(chip)/9.0
		var stone := Art._box(head,Vector3(sin(angle)*0.48,0.011,cos(angle)*0.35),Vector3(0.10,0.025,0.055),"4b4a38","asphalt_chip")
		stone.rotation.y = angle
	var mouth := Art._node(raw,"mouth",Vector3(0,0.045,0.08))
	Art._oval(mouth,Vector3.ZERO,Vector3(0.23,0.009,0.065),"64583a","mouth_edge")
	Art._oval(mouth,Vector3(0,0.007,0),Vector3(0.20,0.006,0.043),"10130d","mouth_opening")
