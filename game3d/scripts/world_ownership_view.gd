extends Node3D
class_name WorldOwnershipView
## Detached facts only. No gameplay references, clocks, processing or collisions.
const Content = preload("res://scripts/content_catalog.gd")
const Surface = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
const UPGRADES: Array[String] = ["cot","locker","desk","generator","radio","route_board"]
const TITLES: Array[String] = ["TAX HELP · NO TAX HELP","THE OFFICE","REGIONAL OFFICE","PAPER AUTHORITY"]
var _built: bool = false
var _surfaces: Dictionary = {}
var _groups: Dictionary = {}
var _meshes: Dictionary = {}
var _last: Dictionary = {}
var _builds: int = 0
var _syncs: int = 0
var _writes: int = 0
var _font: SystemFont
var _sign_materials: Dictionary = {}
var _claim_ids: Array[String] = []
var _claim_centers: Array[Vector2] = []
var _office_center := Vector2.ZERO
var _hideout_centers: Array[Vector2] = []
var _semantic_key: int = 0
var _proximity_key: int = 0
var _cached_center := Vector2.ZERO
var _has_snapshot: bool = false
var _fact_builds: int = 0

static func _truth(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return float(value) != 0.0 and not is_nan(float(value))
	if value is String: return not value.is_empty()
	return true

static func _dict(value: Variant) -> Dictionary: return value if value is Dictionary else {}

static func facts(snapshot: Dictionary, player_center: Vector2) -> Dictionary:
	if not player_center.is_finite(): return {}
	var office: Dictionary = _dict(snapshot.get("office"))
	var upgrades: Dictionary = _dict(office.get("upgrades"))
	var claims: Dictionary = _dict(snapshot.get("districtClaims"))
	var flags: Dictionary = _dict(snapshot.get("flags"))
	var count: int = 0
	var signs: Dictionary = {}
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]):
		var raw: Variant = claims.get(site.id)
		if raw is bool and raw: count += 1
		var visible_sign: bool = _truth(raw)
		signs[str(site.id)] = {"visible":visible_sign,"caption":visible_sign and player_center.distance_squared_to(Vector2(site.sign.x,site.sign.y)) < 10000.0}
	var owned: bool = _truth(office.get("owned"))
	var title: String = TITLES[3] if count >= 11 else TITLES[2] if count >= 4 else TITLES[1] if owned else TITLES[0]
	var bits: Dictionary = {}
	for id: String in UPGRADES: bits[id] = _truth(upgrades.get(id))
	var door: Dictionary = Content.definition("src/systems/campaigns.js","OFFICE_DOOR",{})
	var office_facts: Dictionary = {"owned":owned,"claims":count,"title":title,"locked":not owned,
		"door_color":"#5a4028" if owned else "#2a211b","panel_color":"#8a6840" if owned else "#3a3028",
		"knob_color":"#e8c040" if owned else "#77665a","sign_border":"#e8c040" if owned else "#5a4838",
		"sign_color":"#d4c896" if owned else "#8a7868","upgrades":bits,
		"paper_count":mini(6,1+count) if bits.desk else 0,"mailbox":count >= 1,"trim":count >= 8,
		"e_hint":player_center.distance_squared_to(Vector2(door.x+door.w*0.5,door.y+door.h*0.5)) < 4096.0}
	var hideouts: Dictionary = {}
	var doors: Dictionary = Content.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{})
	for id: String in ["scrap","mom"]:
		var d: Dictionary = doors[id]
		var is_owned: bool = _truth(flags.get(id+"HideoutOwned"))
		hideouts[id] = {"visible":is_owned,"door_color":"#6a4a30" if id == "mom" else "#4a3a28",
			"panel_color":"#8a6440" if id == "mom" else "#5a4830",
			"e_hint":is_owned and player_center.distance_squared_to(Vector2(d.x+d.w*0.5,d.y+d.h*0.5)) < 3600.0}
	return {"office":office_facts,"claims":signs,"hideouts":hideouts}

func _group(id: String,at: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new(); node.name = id; node.position = at; add_child(node)
	_groups[id] = node; return node

func _box(parent: Node3D,label: String,at: Vector3,size: Vector3,color: String,kind: String = "wood") -> MeshInstance3D:
	var key: String = str(size)
	if not _meshes.has(key):
		var box := BoxMesh.new(); box.size = size; _meshes[key] = box
	var node := MeshInstance3D.new(); node.name = label; node.mesh = _meshes[key]
	node.material_override = Surface.material(kind,color)
	node.position = at; parent.add_child(node); return node

func _label(parent: Node3D,text_value: String,at: Vector3,pixel: float,color: String) -> Label3D:
	var label := Label3D.new(); label.text = text_value; label.position = at
	label.font = _font; label.font_size = 48; label.pixel_size = pixel
	label.modulate = Color(color); label.outline_modulate = Color("211b16"); label.outline_size = 3
	label.no_depth_test = false; label.double_sided = false; label.shaded = true
	parent.add_child(label); return label

func _batch(node: Node3D) -> void: Batcher.batch_children(node,0.0)

func build(world: Node3D) -> Dictionary:
	if _built: return inspect()
	if world == null or not world.has_method("ownership_surfaces"): return {}
	var surfaces: Dictionary = world.ownership_surfaces()
	if surfaces.is_empty(): return {}
	_surfaces = surfaces.duplicate(true)
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]):
		_claim_ids.append(str(site.id)); _claim_centers.append(Vector2(site.sign.x,site.sign.y))
	var door: Dictionary = Content.definition("src/systems/campaigns.js","OFFICE_DOOR",{})
	_office_center = Vector2(door.x+door.w*0.5,door.y+door.h*0.5)
	var hideouts: Dictionary = Content.definition("src/systems/daily_hideouts.js","HIDEOUT_DOORS",{})
	for id: String in ["scrap","mom"]:
		var d: Dictionary = hideouts[id]
		_hideout_centers.append(Vector2(d.x+d.w*0.5,d.y+d.h*0.5))
	_font = SystemFont.new(); _font.font_names = PackedStringArray(["Courier New","monospace"]); _font.font_weight = 700
	_sign_materials = {false:Surface.material("wood","5a4838"),true:Surface.material("wood","e8c040")}
	_office()
	for id: String in _surfaces.claims: _claim(id,_surfaces.claims[id])
	for id: String in _surfaces.hideouts: _hatch(id,_surfaces.hideouts[id])
	for key: String in _groups: _groups[key].visible = false
	_built = true; _builds += 1
	return inspect()

func _office() -> void:
	var anchor: Vector3 = _surfaces.office.front
	for owned: bool in [false,true]:
		var suffix: String = "owned" if owned else "locked"
		var door := _group("door_"+suffix,anchor+Vector3(-1.85,0,0.02))
		_box(door,"door_wood",Vector3(0,1.12,0),Vector3(0.92,2.18,0.055),"5a4028" if owned else "2a211b")
		_box(door,"door_panel",Vector3(0,1.12,0.04),Vector3(0.72,1.86,0.035),"8a6840" if owned else "3a3028")
		_box(door,"knob",Vector3(0.31,1.06,0.075),Vector3(0.06,0.06,0.04),"e8c040" if owned else "77665a","painted_metal")
		if not owned:
			_box(door,"lock",Vector3(-0.13,1.18,0.075),Vector3(0.22,0.23,0.04),"0a0805","painted_metal")
			_box(door,"lock_inset",Vector3(-0.13,1.18,0.10),Vector3(0.11,0.13,0.02),"604020","painted_metal")
		_batch(door)
	# One text resource per title; materials are swapped only at ownership changes.
	for index: int in range(TITLES.size()):
		var sign := _group("title_"+str(index),_surfaces.office.fascia)
		_box(sign,"sign_back",Vector3.ZERO,Vector3(6.8,0.64,0.06),"0a0805")
		var border := _box(sign,"sign_border",Vector3(0,0,0.035),Vector3(6.69,0.53,0.02),"5a4838")
		border.set_meta("ownership_border",true)
		_box(sign,"sign_face",Vector3(0,0,0.05),Vector3(6.61,0.45,0.02),"0a0805")
		var label: Label3D = _label(sign,TITLES[index],Vector3(0,-0.015,0.068),0.0086,"8a7868")
		label.name = "caption"
		# The two mutable leaves remain distinct; the static back/face can batch.
		_batch(sign)
	var board := _group("upgrade_route_board",anchor+Vector3(3.25,1.7,0.07))
	_box(board,"board_frame",Vector3.ZERO,Vector3(1.25,1.45,0.09),"5a4028")
	_box(board,"board_paper",Vector3(0,0,0.06),Vector3(1.08,1.29,0.025),"d4c896","plain")
	for row: int in range(5): _box(board,"route_line",Vector3(-0.08,-0.42+row*0.21,0.08),Vector3(0.65 if row%2 == 0 else 0.83,0.035,0.015),"5a4028","plain")
	_batch(board)
	var locker := _group("upgrade_locker",anchor+Vector3(-3.55,1.05,0.07))
	_box(locker,"locker",Vector3.ZERO,Vector3(1.12,1.85,0.12),"384038","painted_metal")
	for x: float in [-0.48,0.48]: _box(locker,"seam",Vector3(x,0,0.075),Vector3(0.025,1.7,0.02),"171a17","plain")
	for y: float in [0.5,0.62,0.74]: _box(locker,"vent",Vector3(-0.1,y,0.075),Vector3(0.65,0.035,0.025),"171a17","plain")
	_box(locker,"latch",Vector3(0.34,-0.05,0.09),Vector3(0.08,0.21,0.045),"c08038","painted_metal"); _batch(locker)
	var cot := _group("upgrade_cot",anchor+Vector3(-6.15,0.75,0.07))
	_box(cot,"folded_cot",Vector3.ZERO,Vector3(2.24,0.58,0.13),"6a5840","fabric")
	for x: float in [-1.0,1.0]: _box(cot,"cot_leg",Vector3(x,-0.39,0),Vector3(0.10,0.32,0.10),"29231c","painted_metal")
	_box(cot,"cot_rail",Vector3(0,-0.27,0.09),Vector3(2.28,0.06,0.04),"29231c","painted_metal"); _batch(cot)
	var generator := _group("upgrade_generator",anchor+Vector3(6.4,0.75,0.07))
	_box(generator,"generator",Vector3.ZERO,Vector3(1.8,1.18,0.13),"3a382f","painted_metal")
	_box(generator,"control",Vector3(-0.34,0.11,0.085),Vector3(0.4,0.4,0.05),"c08038","painted_metal")
	for row: int in range(4): _box(generator,"vent",Vector3(0.35,-0.27+row*0.15,0.085),Vector3(0.42,0.035,0.03),"171a17","plain")
	_box(generator,"wire",Vector3(-1.0,-0.27,0.03),Vector3(0.5,0.045,0.04),"8a3a3a","rubber"); _batch(generator)
	var radio := _group("upgrade_radio",anchor+Vector3(6.0,float(_surfaces.office.height),0))
	for side: float in [-1.0,1.0]:
		var mast: MeshInstance3D = _box(radio,"antenna",Vector3(side*0.28,0.74,0),Vector3(0.055,1.6,0.055),"8a7868","painted_metal")
		mast.rotation.z = side*0.34
	_box(radio,"cap",Vector3(0,1.52,0),Vector3(0.16,0.16,0.12),"d06030","painted_metal"); _batch(radio)
	for index: int in range(6):
		var paper := _group("paper_"+str(index),anchor+Vector3(-5.65+index*0.31,2.53+(index%2)*0.07,0.08))
		_box(paper,"paper",Vector3.ZERO,Vector3(0.24,0.17,0.025),"d4c896","plain"); _batch(paper)
	var mailbox := _group("mailbox",anchor+Vector3(-4.85,0.31,0.07))
	_box(mailbox,"mailbox",Vector3.ZERO,Vector3(1.2,0.62,0.11),"5a4830")
	_box(mailbox,"slot",Vector3(0,0.09,0.075),Vector3(0.88,0.12,0.03),"d4c896","plain"); _batch(mailbox)
	var trim := _group("trim",anchor+Vector3(0,3.91,0.03))
	_box(trim,"trim_back",Vector3.ZERO,Vector3(float(_surfaces.office.width)+0.5,0.24,0.06),"8a3a3a")
	for index: int in range(17): _box(trim,"stripe",Vector3(-8.1+index*1.01,0,0.04),Vector3(0.5,0.24,0.025),"c08038","painted_metal")
	_batch(trim)

func _claim(id: String,point: Vector3) -> void:
	var group := _group("claim_"+id,point)
	_box(group,"post",Vector3(0,0.61,0),Vector3(0.11,1.22,0.10),"2a1f10")
	_box(group,"foot",Vector3(0,0.045,0),Vector3(0.34,0.09,0.28),"2a1f10")
	_box(group,"board",Vector3(0,1.28,0),Vector3(1.12,0.56,0.095),"2a1f10")
	_box(group,"face",Vector3(0,1.28,0.058),Vector3(0.98,0.43,0.025),"d4c896","plain")
	for index: int in range(4): _box(group,"ink",Vector3(-0.32+index*0.21,1.28,0.076),Vector3(0.12,0.09 if index%2 else 0.17,0.012),"8a3a3a","plain")
	_batch(group)
	var caption := _group("caption_"+id,point)
	_label(caption,"THE OFFICE CLAIMS",Vector3(0,1.86,0.07),0.0045,"d4c896")

func _hatch(id: String,rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var group := _group("hideout_"+id,Vector3(center.x,0.018,center.y))
	var base: String = "6a4a30" if id == "mom" else "4a3a28"
	var panel: String = "8a6440" if id == "mom" else "5a4830"
	_box(group,"ground_door",Vector3.ZERO,Vector3(rect.size.x,0.014,rect.size.y),base)
	_box(group,"panel",Vector3(0,0.011,0),Vector3(rect.size.x-0.24,0.009,rect.size.y-0.32),panel)
	_box(group,"knob",Vector3(rect.size.x*0.5-0.24,0.021,0),Vector3(0.08,0.012,0.08),"c8a060","painted_metal")
	for z: float in [-0.38,0.38]: _box(group,"hinge",Vector3(-rect.size.x*0.5+0.06,0.02,z),Vector3(0.12,0.008,0.08),"604020","painted_metal")
	_batch(group)

func _visible(id: String,value: bool) -> void:
	var node: Node3D = _groups[id]
	if node.visible != value: node.visible = value; _writes += 1

func _semantic(snapshot: Dictionary) -> int:
	var office: Dictionary = _dict(snapshot.get("office"))
	var upgrades: Dictionary = _dict(office.get("upgrades"))
	var claims: Dictionary = _dict(snapshot.get("districtClaims"))
	var flags: Dictionary = _dict(snapshot.get("flags"))
	var key: int = 1 if _truth(office.get("owned")) else 0
	for index: int in range(UPGRADES.size()):
		if _truth(upgrades.get(UPGRADES[index])): key |= 1 << (1+index)
	for index: int in range(_claim_ids.size()):
		var value: Variant = claims.get(_claim_ids[index])
		if _truth(value): key |= 1 << (7+index)
		if value is bool and value: key |= 1 << (18+index)
	if _truth(flags.get("scrapHideoutOwned")): key |= 1 << 29
	if _truth(flags.get("momHideoutOwned")): key |= 1 << 30
	return key

func _proximity(center: Vector2,semantic: int) -> int:
	var key: int = 1 if center.distance_squared_to(_office_center) < 4096.0 else 0
	for index: int in range(_hideout_centers.size()):
		if (semantic & (1 << (29+index))) != 0 and center.distance_squared_to(_hideout_centers[index]) < 3600.0: key |= 1 << (1+index)
	for index: int in range(_claim_centers.size()):
		if (semantic & (1 << (7+index))) != 0 and center.distance_squared_to(_claim_centers[index]) < 10000.0: key |= 1 << (3+index)
	return key

func sync(snapshot: Dictionary,player_center: Vector2) -> bool:
	if not _built or not player_center.is_finite(): return false
	_syncs += 1
	var semantic: int = _semantic(snapshot)
	if _has_snapshot and semantic == _semantic_key and player_center == _cached_center: return true
	var proximity: int = _proximity(player_center,semantic)
	if _has_snapshot and semantic == _semantic_key and proximity == _proximity_key:
		_cached_center = player_center; return true
	var next: Dictionary = facts(snapshot,player_center)
	_semantic_key = semantic; _proximity_key = proximity; _cached_center = player_center; _has_snapshot = true
	_fact_builds += 1
	if next == _last: return true
	var office: Dictionary = next.office
	_visible("door_owned",office.owned); _visible("door_locked",office.locked)
	for index: int in range(TITLES.size()): _visible("title_"+str(index),TITLES[index] == office.title)
	if _last.is_empty() or _last.office.owned != office.owned:
		for index: int in range(TITLES.size()):
			var sign: Node3D = _groups["title_"+str(index)]
			for child: Node in sign.get_children():
				if child is MeshInstance3D and child.get_meta("ownership_border",false): child.material_override = _sign_materials[office.owned]; _writes += 1
				if child is Label3D: child.modulate = Color(office.sign_color); _writes += 1
	for id: String in UPGRADES:
		if id != "desk": _visible("upgrade_"+id,office.upgrades[id])
	for index: int in range(6): _visible("paper_"+str(index),index < int(office.paper_count))
	_visible("mailbox",office.mailbox); _visible("trim",office.trim)
	for id: String in next.claims:
		_visible("claim_"+id,next.claims[id].visible); _visible("caption_"+id,next.claims[id].caption)
	for id: String in next.hideouts: _visible("hideout_"+id,next.hideouts[id].visible)
	_last = next; return true

func inspect() -> Dictionary:
	var enabled: Array[String] = []
	for key: String in _groups:
		if _groups[key].visible: enabled.append(key)
	return {"built":_built,"builds":_builds,"syncs":_syncs,"writes":_writes,"fact_builds":_fact_builds,"groups":_groups.size(),
		"mesh_cache":_meshes.size(),"visible":enabled,"facts":_last.duplicate(true),"surfaces":_surfaces.duplicate(true)}
