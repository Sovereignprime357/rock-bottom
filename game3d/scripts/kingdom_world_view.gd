class_name KingdomWorldView
extends Node3D
## Detached source facts projected into a fixed, nonblocking world-art bank.
const Content = preload("res://scripts/content_catalog.gd")
const Surface = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
const IDS: Array[String] = ["blue_tarp","cart_cavalry","copper_choir","emperor"]
const FLAGS: Array[String] = ["blueTarpCleared","cartKeepCleared","copperChoirCleared","throneDitchCleared"]
const PALETTES: Array[Array] = [["111418","34485a","e8c040"],["17130d","d4c896","8a3a3a"],["100b08","8a5b3a","d06030"],["0a0805","5a5548","e8c040"]]
var _built: bool = false
var _groups: Dictionary = {}
var _anchors: Dictionary = {}
var _facts: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _font: SystemFont
var _writes: int = 0
var _syncs: int = 0

static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _truth(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return not is_nan(float(value)) and float(value) != 0.0
	if value is String: return not value.is_empty()
	return true

static func _bits(value: Variant) -> int:
	var number: float = 0.0
	if value is bool: number = 1.0 if value else 0.0
	elif value is int or value is float: number = float(value)
	elif value is String and value.strip_edges().is_valid_float(): number = value.strip_edges().to_float()
	if not is_finite(number): return 0
	# Source bitwise conversion truncates, then wraps modulo 2^32.
	var wrapped: float = fposmod(floorf(number) if number >= 0 else ceilf(number),4294967296.0)
	return int(wrapped)

static func _definitions() -> Array[Dictionary]:
	var clans: Dictionary = Content.definition("src/systems/campaigns.js","KINGDOM_CLANS",{})
	var result: Array[Dictionary] = []
	for id: String in IDS:
		result.append(Content.definition("src/systems/campaigns.js","KINGDOM_EMPEROR",{}) if id == "emperor" else clans.get(id,{}))
	return result

static func facts(snapshot: Dictionary) -> Dictionary:
	var kingdom: Dictionary = _dict(snapshot.get("kingdom"))
	var flags: Dictionary = _dict(snapshot.get("flags"))
	var banners: Dictionary = {}; var marks: Dictionary = {}
	var definitions: Array[Dictionary] = _definitions()
	var bits: int = _bits(kingdom.get("marks"))
	for index: int in range(IDS.size()):
		var id: String = IDS[index]; var definition: Dictionary = definitions[index]
		banners[id] = {"alpha":0.58 if _truth(flags.get(FLAGS[index])) else 1.0}
		var rows: Array = definition.get("marks",[])
		for mark_index: int in range(rows.size()):
			var key: String = id+":"+str(mark_index)
			if kingdom.get("stage") != definition.get("marksStage"):
				marks[key] = {"visible":false}; continue
			var done: bool = (bits & (1 << mark_index)) != 0
			marks[key] = {"visible":true,"done":done,"text":"✓" if done else str(mark_index+1),
				"border":"#6f765e" if done else "#e8c040","text_color":"#6f765e" if done else "#d4c896","dashed":not done}
	return {"banners":banners,"marks":marks}

static func _point(value: Dictionary) -> Vector3:
	return Content.to_world(Vector2(value.x,value.y))

func _prepare_anchors(world: Node3D) -> Dictionary:
	if world == null or not world.has_method("obstacle_records"): return {}
	var fence := AABB(); var found: bool = false
	var newsbox := AABB(); var found_newsbox: bool = false
	for obstacle: Dictionary in world.obstacle_records():
		var bounds: AABB = obstacle.bounds
		if obstacle.get("owner") == "props:143" and bounds.size.y > 1.5 and bounds.size.x > 1.0:
			fence = bounds; found = true
		elif obstacle.get("owner") == "decor:81" and bounds.size.y > 0.8 and bounds.size.x > 0.4:
			newsbox = bounds; found_newsbox = true
	if not found or not found_newsbox: return {}
	var anchors: Dictionary = {"banners":{},"marks":{}}
	var definitions: Array[Dictionary] = _definitions()
	for index: int in range(IDS.size()):
		var id: String = IDS[index]; var definition: Dictionary = definitions[index]
		if not definition.get("banner") is Dictionary: return {}
		anchors.banners[id] = {"source":Vector2(definition.banner.x,definition.banner.y),"point":_point(definition.banner)}
		var rows: Array = definition.get("marks",[])
		for mark_index: int in range(rows.size()):
			var mark: Dictionary = rows[mark_index]; var point: Vector3 = _point(mark)
			var pose := Transform3D(Basis(Vector3.RIGHT,-PI*0.5),point+Vector3.UP*0.025)
			var mount: String = "ground"
			if id == "cart_cavalry" and mark_index == 0:
				# Actual north fence face; canonical target remains untouched.
				if absf(point.z-fence.position.z) > 0.002 or point.x-0.4 < fence.position.x or point.x+0.4 > fence.end.x: return {}
				pose = Transform3D(Basis(Vector3.UP,PI),Vector3(point.x,1.1,fence.position.z-0.012))
				mount = "fence"
			elif id == "blue_tarp" and mark_index == 0:
				# The source newsbox occupies this exact ground target. Paint its
				# lower front, below the existing paper/window, without moving it.
				if absf(point.x-newsbox.get_center().x) > 0.002 or absf(point.z-newsbox.get_center().z) > 0.002 or newsbox.size.x < 0.4: return {}
				pose = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.45),Vector3(point.x,newsbox.position.y+0.24,newsbox.end.z+0.012))
				mount = "newsbox"
			anchors.marks[id+":"+str(mark_index)] = {"source":Vector2(mark.x,mark.y),"transform":pose,"mount":mount}
	anchors.fence = fence
	anchors.newsbox = newsbox
	return anchors

func _material(color: String,kind: String,alpha: float) -> StandardMaterial3D:
	var key: String = color+"/"+kind+"/"+str(alpha)
	if not _materials.has(key):
		var material: StandardMaterial3D = Surface.material(kind,color)
		if alpha < 1.0:
			material = material.duplicate() as StandardMaterial3D
			material.albedo_color.a = alpha
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = material
	return _materials[key]

func _box(parent: Node3D,at: Vector3,size: Vector3,color: String,kind: String = "plain",alpha: float = 1.0) -> void:
	var key: String = str(size)
	if not _meshes.has(key):
		var mesh := BoxMesh.new(); mesh.size = size; _meshes[key] = mesh
	var node := MeshInstance3D.new(); node.mesh = _meshes[key]
	node.material_override = _material(color,kind,alpha); node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func _group(id: String,pose: Transform3D) -> Node3D:
	var node := Node3D.new(); node.name = id; node.transform = pose; node.visible = false
	add_child(node); _groups[id] = node; return node

func _banner_ink(parent: Node3D,side: float,color: String,alpha: float) -> void:
	# The generic batcher excludes arbitrary transparent objects. These disjoint
	# same-plane, same-color motifs can safely share one face-local draw instead.
	var motif := Node3D.new(); parent.add_child(motif)
	for y: float in [-0.13,0.13]: _box(motif,Vector3(0,1.34+y,side*0.044),Vector3(0.75,0.045,0.008),color)
	for x: float in [-0.30,-0.10,0.10,0.30]: _box(motif,Vector3(x,1.34,side*0.044),Vector3(0.065,0.17,0.008),color)
	Batcher.batch_children(motif,0.0)
	for child: Node in motif.get_children():
		if child is MeshInstance3D: child.material_override = _material(color,"plain",alpha)
		motif.remove_child(child); parent.add_child(child)
	motif.free()

func _banner(index: int,faded: bool) -> void:
	var id: String = IDS[index]; var alpha: float = 0.58 if faded else 1.0
	var node := _group("banner_"+id+("_faded" if faded else "_full"),Transform3D(Basis.IDENTITY,_anchors.banners[id].point))
	var colors: Array = PALETTES[index]
	_box(node,Vector3(0,0.76,0),Vector3(0.09,1.52,0.09),colors[0],"wood",alpha)
	_box(node,Vector3(0,0.035,0),Vector3(0.30,0.07,0.28),colors[0],"wood",alpha)
	_box(node,Vector3(0,1.34,0),Vector3(1.12,0.67,0.055),colors[0],"wood",alpha)
	for side: float in [-1.0,1.0]:
		_box(node,Vector3(0,1.34,side*0.033),Vector3(0.98,0.53,0.015),colors[1],"fabric",alpha)
		_banner_ink(node,side,colors[2],alpha)
	Batcher.batch_children(node,0.0)

func _mark(id: String,done: bool) -> void:
	var anchor: Dictionary = _anchors.marks[id]
	var node := _group("mark_"+id.replace(":","_")+("_done" if done else "_open"),anchor.transform)
	var color: String = "6f765e" if done else "e8c040"
	if done:
		for side: float in [-1.0,1.0]:
			_box(node,Vector3(0,side*0.36,0),Vector3(0.72,0.08,0.006),color)
			_box(node,Vector3(side*0.36,0,0),Vector3(0.08,0.72,0.006),color)
	else:
		for offset: float in [-0.30,-0.06,0.18]:
			for side: float in [-1.0,1.0]:
				_box(node,Vector3(offset,side*0.36,0),Vector3(0.12,0.08,0.006),color)
				_box(node,Vector3(side*0.36,offset,0),Vector3(0.08,0.12,0.006),color)
	Batcher.batch_children(node,0.0)
	var label := Label3D.new(); label.name = "mark_text"
	label.text = "✓" if done else str(int(id.get_slice(":",1))+1)
	label.font = _font; label.font_size = 48; label.pixel_size = 0.008
	label.position.z = 0.006; label.modulate = Color("6f765e" if done else "d4c896")
	label.outline_size = 0; label.no_depth_test = false; label.double_sided = false; label.shaded = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(label)

func build(world: Node3D) -> Dictionary:
	if _built: return inspect()
	var prepared: Dictionary = _prepare_anchors(world)
	if prepared.is_empty(): return {}
	_anchors = prepared
	_font = SystemFont.new(); _font.font_names = PackedStringArray(["Courier New","monospace"]); _font.font_weight = 700
	for index: int in range(IDS.size()):
		_banner(index,false); _banner(index,true)
	for id: String in _anchors.marks:
		_mark(id,false); _mark(id,true)
	_built = true; sync({}); return inspect()

func _visible(id: String,value: bool) -> void:
	var node: Node3D = _groups[id]
	if node.visible != value: node.visible = value; _writes += 1

func sync(snapshot: Dictionary) -> void:
	if not _built: return
	_syncs += 1
	var next: Dictionary = facts(snapshot)
	if next == _facts: return
	for id: String in IDS:
		var faded: bool = next.banners[id].alpha < 1.0
		_visible("banner_"+id+"_full",not faded); _visible("banner_"+id+"_faded",faded)
	for id: String in next.marks:
		var row: Dictionary = next.marks[id]
		var prefix: String = "mark_"+id.replace(":","_")
		_visible(prefix+"_open",row.visible and not row.get("done",false))
		_visible(prefix+"_done",row.visible and row.get("done",false))
	_facts = next

func inspect() -> Dictionary:
	var visible_groups: Array[String] = []
	for id: String in _groups:
		if _groups[id].visible: visible_groups.append(id)
	return {"built":_built,"facts":_facts.duplicate(true),"anchors":_anchors.duplicate(true),"visible":visible_groups,"writes":_writes,"syncs":_syncs,"mesh_cache":_meshes.size(),"material_cache":_materials.size()}
