class_name RockBottomIncidentPresentation
extends Node3D
## Detached display only. Source state/time/RNG and actual player pushes stay elsewhere.
const Content = preload("res://scripts/content_catalog.gd")
const Surfaces = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
const Roster = preload("res://scripts/character_roster.gd")
const IDS: Array[String] = ["runaway_mattress","possum_inventory","laundromat_walkout","yuri_receipt","park_dry_committee","ticketed_luggage"]
const ENVELOPES := {
	"runaway_mattress":Vector3(1.16,0.38,1.02),
	"possum_inventory":Vector3(1.52,1.68,0.78),
	"laundromat_walkout":Vector3(0.9,1.21,0.9),
	"ticketed_luggage":Vector3(0.66,0.96,0.46)}
var _world_ref: WeakRef
var _banks: Dictionary = {}
var _wheels: Dictionary = {}
var _pigeons: Dictionary = {}
var _sheets: Array[Node3D] = []
var _water: Array[MeshInstance3D] = []
var _bubbles: Array[MeshInstance3D] = []
var _sock: Node3D
var _built: bool = false
var _last_id: String = ""
var _support_cache: Dictionary = {}
var _stats: Dictionary = {"build_usec":0,"sync_calls":0,"sync_usec":0,"max_sync_usec":0,"banks":0}
var _last_route_report: Dictionary = {"complete":false,"ok":false,"reason":"not_audited"}

func build(world: Node3D) -> Dictionary:
	if _built: return metrics()
	if world == null or not world.has_method(&"obstacle_records"): return {"ok":false,"reason":"missing_world"}
	_world_ref = weakref(world)
	var started: int = Time.get_ticks_usec()
	for id: String in IDS:
		var bank := Node3D.new(); bank.name = id; add_child(bank); _banks[id] = bank
		bank.visible = false
	_mattress(_banks.runaway_mattress); _forklift(_banks.possum_inventory)
	_dryer(_banks.laundromat_walkout); _receipt(_banks.yuri_receipt)
	_sprinkler(_banks.park_dry_committee); _suitcase(_banks.ticketed_luggage)
	for id: String in IDS: Batcher.batch_children(_banks[id])
	_built = true; _stats.build_usec = Time.get_ticks_usec()-started; _stats.banks = _banks.size()
	return metrics()

func _node(parent: Node3D,label: String,at: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new(); node.name = label; parent.add_child(node); node.position = at; return node
func _mesh(parent: Node3D,label: String,mesh: Mesh,at: Vector3,hex: String,kind: String = "painted_metal") -> MeshInstance3D:
	var instance := MeshInstance3D.new(); instance.name = label; instance.mesh = mesh
	instance.material_override = Surfaces.material(kind,hex)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance); instance.position = at; return instance
func _box(parent: Node3D,label: String,size: Vector3,at: Vector3,hex: String,kind: String = "painted_metal") -> MeshInstance3D:
	var mesh := BoxMesh.new(); mesh.size = size; return _mesh(parent,label,mesh,at,hex,kind)
func _round(parent: Node3D,label: String,radius: float,height: float,at: Vector3,hex: String,kind: String = "painted_metal",sides: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = sides; mesh.rings = 1
	return _mesh(parent,label,mesh,at,hex,kind)
func _wheel(parent: Node3D,label: String,at: Vector3,radius: float) -> Node3D:
	var pivot: Node3D = _node(parent,label,at)
	_round(pivot,"rubber",radius,0.13,Vector3.ZERO,"33362d","rubber").rotation.x = PI*0.5
	_round(pivot,"hub",radius*0.4,0.14,Vector3.ZERO,"826b4a").rotation.x = PI*0.5
	Batcher.batch_children(pivot); return pivot
func _mattress(bank: Node3D) -> void:
	# Folded width fits the source18px endpoint padding including the3px sine.
	bank.scale.x = 1.16/1.44
	_box(bank,"stained_ticking",Vector3(1.4,0.24,0.98),Vector3(0,0.22,0),"aaa184","fabric")
	for z: float in [-0.48,0.48]:
		_box(bank,"rolled_seam",Vector3(1.4,0.035,0.025),Vector3(0,0.33,z),"77715b","fabric")
	for x: float in [-0.69,0.69]:
		_box(bank,"end_seam",Vector3(0.025,0.035,0.96),Vector3(x,0.33,0),"77715b","fabric")
	for x: float in [-0.5,-0.17,0.16,0.49]:
		_box(bank,"bed_slat",Vector3(0.055,0.04,0.89),Vector3(x,0.08,0),"6b5840","wood")
	for point: Vector2 in [Vector2(-0.4,0.2),Vector2(0.13,-0.19),Vector2(0.42,0.25)]:
		_box(bank,"water_stain",Vector3(0.29,0.008,0.19),Vector3(point.x,0.344,point.y),"817953","fabric")
	var corner: MeshInstance3D = _box(bank,"folded_corner",Vector3(0.28,0.06,0.2),Vector3(0.54,0.32,-0.38),"b8ae8c","fabric"); corner.rotation.x = -0.24
	for index: int in range(4):
		var spring: MeshInstance3D = _round(bank,"exposed_spring",0.035,0.01,Vector3(0.68,0.14+index*0.025,0.30),"806e50", "painted_metal",8); spring.rotation.z = 0.2
func _forklift(bank: Node3D) -> void:
	_box(bank,"rust_chassis",Vector3(0.94,0.36,0.63),Vector3(-0.16,0.43,0),"8c6943")
	_box(bank,"mold_counterweight",Vector3(0.24,0.48,0.66),Vector3(-0.60,0.58,0),"657050")
	_box(bank,"black_seat",Vector3(0.34,0.12,0.36),Vector3(-0.2,0.76,0),"363d32","rubber")
	_box(bank,"seat_back",Vector3(0.08,0.32,0.36),Vector3(-0.39,0.92,0),"363d32","rubber")
	for z: float in [-0.28,0.28]:
		_box(bank,"mast",Vector3(0.07,1.30,0.07),Vector3(0.4,0.82,z),"5a5c49")
		_box(bank,"fork",Vector3(0.50,0.05,0.06),Vector3(0.51,0.16,z),"8e8063")
		_box(bank,"cage_rear",Vector3(0.045,0.88,0.045),Vector3(-0.54,1.13,z),"756a4f")
		_box(bank,"cage_roof",Vector3(1.03,0.055,0.045),Vector3(-0.07,1.57,z),"756a4f")
	_box(bank,"roof_crossbar",Vector3(0.045,0.055,0.58),Vector3(-0.54,1.57,0),"756a4f")
	var wheels: Array[Node3D] = []
	for x: float in [-0.48,0.25]:
		for z: float in [-0.325,0.325]: wheels.append(_wheel(bank,"wheel",Vector3(x,0.25,z),0.20))
	_wheels.possum_inventory = wheels
	var possum: Node3D = Roster.create(&"possum",73)
	if possum != null:
		bank.add_child(possum); possum.name = "decorative_possum"; possum.position = Vector3(-0.12,0.80,0); possum.rotation.y = PI*0.5; possum.scale = Vector3.ONE*0.72
	_box(bank,"clipboard",Vector3(0.035,0.29,0.20),Vector3(0.15,1.08,0.22),"766244","wood")
	_box(bank,"inventory_paper",Vector3(0.008,0.24,0.17),Vector3(0.173,1.08,0.22),"c3b58d","plain")
	for index: int in range(4): _box(bank,"inventory_lines",Vector3(0.009,0.009,0.11),Vector3(0.18,1.15-index*0.04,0.22),"655d45","plain")
func _dryer(bank: Node3D) -> void:
	_box(bank,"cream_cabinet",Vector3(0.86,0.95,0.72),Vector3(0,0.64,0),"aaa78e")
	_box(bank,"dark_plinth",Vector3(0.82,0.14,0.69),Vector3(0,0.15,0),"545c4f")
	_round(bank,"drum_rim",0.29,0.035,Vector3(0,0.62,0.374),"888b77").rotation.x = PI*0.5
	_round(bank,"drum_void",0.24,0.042,Vector3(0,0.62,0.389),"2f3b35").rotation.x = PI*0.5
	_round(bank,"dryer_dial",0.055,0.04,Vector3(0.24,1.025,0.375),"4b5546").rotation.x = PI*0.5
	_box(bank,"dead_display",Vector3(0.25,0.055,0.024),Vector3(-0.12,1.025,0.376),"4b5546")
	_sock = _node(bank,"one_wet_sock",Vector3(0,0.62,0.418))
	_box(_sock,"sock_leg",Vector3(0.09,0.22,0.025),Vector3(0,0.02,0),"9b9476","fabric")
	_box(_sock,"sock_toe",Vector3(0.16,0.065,0.025),Vector3(0.035,-0.07,0),"827c62","fabric"); Batcher.batch_children(_sock)
	for x: float in [-0.31,0.31]:
		for z: float in [-0.26,0.26]: _round(bank,"rolling_foot",0.065,0.05,Vector3(x,0.08,z),"444b40","rubber",8).rotation.x = PI*0.5
	for index: int in range(6):
		var bubble: MeshInstance3D = _round(bank,"soap_bubble",0.025+0.006*(index%3),0.015,Vector3.ZERO,"879786","plain",8)
		bubble.set_meta("animated",true); _bubbles.append(bubble)
func _receipt(bank: Node3D) -> void:
	for index: int in range(12):
		var sheet: Node3D = _node(bank,"receipt_%02d" % index)
		_box(sheet,"paper",Vector3(0.56,0.012,0.22),Vector3.ZERO,"c2b58e","plain")
		for line: int in range(3): _box(sheet,"printed_bar",Vector3(0.28-line*0.035,0.003,0.015),Vector3(-0.06,0.009,-0.055+line*0.05),"655c43","plain")
		Batcher.batch_children(sheet); _sheets.append(sheet)
func _pigeon(parent: Node3D,index: int) -> Node3D:
	var bird: Node3D = _node(parent,"pigeon_%d" % index)
	# Palette batching can combine disjoint shapes into a larger AABB. Contain that
	# transformed box too, including corners with no authored vertex.
	bird.scale = Vector3(0.86,1.0,0.86)
	# Every mesh AABB corner stays within radius .10 and local Y .02..38.
	# That also contains the whole bird in the existing world query at any heading.
	_oval(bird,"breast",Vector3(0.104,0.15,0.15),Vector3(0,0.15,-0.005),"6a756b")
	_oval(bird,"neck",Vector3(0.075,0.15,0.075),Vector3(0,0.265,0.032),"627961")
	_oval(bird,"head",Vector3(0.065,0.075,0.07),Vector3(0,0.335,0.04),"718275")
	for side: float in [-1.0,1.0]:
		_oval(bird,"folded_wing",Vector3(0.025,0.086,0.126),Vector3(side*0.046,0.167,-0.011),"505d55")
		_oval(bird,"eye",Vector3(0.012,0.012,0.012),Vector3(side*0.032,0.346,0.057),"303b31","plain")
		_round(bird,"ankle",0.006,0.043,Vector3(side*0.033,0.046,0.012),"9c6c4c","plain",6)
		for toe: float in [-0.006,0.006]:
			_box(bird,"toe",Vector3(0.009,0.012,0.04),Vector3(side*0.033+toe,0.027,0.025),"9c6c4c","plain")
	var tail: MeshInstance3D = _box(bird,"tail_feathers",Vector3(0.045,0.023,0.045),Vector3(0,0.135,-0.068),"4a584e","fabric"); tail.rotation.x = -0.20
	var beak := CylinderMesh.new(); beak.bottom_radius = 0.018; beak.top_radius = 0; beak.height = 0.048; beak.radial_segments = 6; beak.rings = 1
	_mesh(bird,"beak",beak,Vector3(0,0.327,0.071),"ac9a70","plain").rotation.x = PI*0.5
	Batcher.batch_children(bird); return bird
func _oval(parent: Node3D,label: String,size: Vector3,at: Vector3,hex: String,kind: String = "fabric") -> MeshInstance3D:
	var mesh := SphereMesh.new(); mesh.radius = 0.5; mesh.height = 1.0; mesh.radial_segments = 8; mesh.rings = 4
	var instance: MeshInstance3D = _mesh(parent,label,mesh,at,hex,kind); instance.scale = size; return instance
func _sprinkler(bank: Node3D) -> void:
	_round(bank,"rust_base",0.27,0.09,Vector3(0,0.10,0),"806544")
	_round(bank,"water_pipe",0.055,0.48,Vector3(0,0.36,0),"728171")
	_box(bank,"spray_head",Vector3(0.27,0.09,0.11),Vector3(0,0.60,0),"9c8860")
	for index: int in range(24):
		var bead: MeshInstance3D = _box(bank,"water_segment",Vector3(0.028,0.026,0.14),Vector3.ZERO,"839b91","plain")
		bead.set_meta("animated",true); _water.append(bead)
	var birds: Array[Node3D] = []
	for index: int in range(6): birds.append(_pigeon(bank,index))
	_pigeons.park_dry_committee = birds
func _suitcase(bank: Node3D) -> void:
	_box(bank,"worn_leather_case",Vector3(0.61,0.61,0.39),Vector3(0,0.49,0),"7c6446","fabric")
	for x: float in [-0.23,0.23]: _box(bank,"leather_strap",Vector3(0.055,0.63,0.405),Vector3(x,0.49,0),"4f5040","fabric")
	_box(bank,"handle_top",Vector3(0.24,0.035,0.05),Vector3(0,0.91,0),"494b3b","rubber")
	for x: float in [-0.10,0.10]: _box(bank,"handle_upright",Vector3(0.035,0.11,0.05),Vector3(x,0.85,0),"494b3b","rubber")
	_box(bank,"punched_ticket",Vector3(0.13,0.19,0.015),Vector3(0.07,0.63,0.214),"c3b48d","plain")
	_box(bank,"ticket_hole",Vector3(0.025,0.025,0.018),Vector3(0.07,0.68,0.22),"4a4c3c","plain")
	var feet: Array[Node3D] = []
	for x: float in [-0.20,0.20]:
		var foot := _node(bank,"foot",Vector3(x,0.10,0))
		_box(foot,"leg",Vector3(0.045,0.13,0.045),Vector3(0,0.04,0),"5c5e49")
		_box(foot,"shoe",Vector3(0.10,0.05,0.20),Vector3(0,0,0.04),"424a3d","rubber"); Batcher.batch_children(foot); feet.append(foot)
	_wheels.ticketed_luggage = feet
	var birds: Array[Node3D] = []
	for index: int in range(3): birds.append(_pigeon(bank,index))
	_pigeons.ticketed_luggage = birds

static func display_point(incident: Dictionary) -> Vector2:
	var actor: Dictionary = incident.actors[0]
	var source := Vector2(actor.x,actor.y)
	if incident.id == "ticketed_luggage":
		# The source optional28px avoidance remains in actor.y. Clear the retained
		# signal with a display-only north arc that ends before the final stop.
		if actor.x > 1200 and actor.x < 1320: source.y -= 12.0*sin(PI*(float(actor.x)-1200.0)/120.0)
		return source
	if incident.id == "possum_inventory":
		# Two small southward arcs retain both canonical endpoints and source timing.
		var trash_progress: float = clampf((float(actor.x)-720.0)/220.0,0.0,1.0)
		var tip: float = sin(trash_progress*PI)*14.0
		var end_progress: float = clampf((float(incident.t)-21000.0)/9000.0,0.0,1.0)
		return source+Vector2(0,tip+sin(end_progress*PI)*22.0)
	if incident.id != "laundromat_walkout": return source
	var q: float = minf(1.0,float(incident.t)/24500.0)
	# Existing south doorway, exact source endpoints. Maximum source displacement<100px.
	var points: Array[Vector2] = [Vector2(1540,1190),Vector2(1637.2,1202.15),Vector2(1640,1258),Vector2(1734,1258),Vector2(1900,1235)]
	var times: Array[float] = [0.0,0.27,0.4,0.6,1.0]
	for index: int in range(1,times.size()):
		if q <= times[index]:
			var point: Vector2 = points[index-1].lerp(points[index],(q-times[index-1])/(times[index]-times[index-1]))
			point.y += sin(float(incident.t)/170.0)*3.0
			return point
	return source
func _support(point: Vector3) -> float:
	var key := Vector2(point.x,point.z)
	if _support_cache.has(key): return _support_cache[key]
	var world: Node3D = _world_ref.get_ref() if _world_ref != null else null
	if world == null or not world.is_inside_tree(): return 0.06
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.5,point-Vector3.UP*0.1,1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	var height: float = maxf(0.06,float(hit.position.y)+0.025) if not hit.is_empty() else 0.06
	_support_cache[key] = height; return height
func sync(view: Dictionary,visual_ms: float) -> bool:
	if not _built or not is_finite(visual_ms) or visual_ms < 0: return false
	var active: Variant = view.get("active")
	if active == null: clear(); return true
	if not active is Dictionary or active.get("id","") not in IDS: return false
	var started: int = Time.get_ticks_usec(); var id: String = active.id; var bank: Node3D = _banks[id]
	if id != _last_id:
		for key: String in IDS: _banks[key].visible = key == id
		_support_cache.clear()
		_last_id = id
	bank.position = Vector3.ZERO; bank.rotation = Vector3.ZERO
	if ENVELOPES.has(id): bank.position = Content.to_world(display_point(active),0.055)
	match id:
		"runaway_mattress": bank.rotation.y = PI*0.5 if active.road.axis == "v" else 0.0
		"possum_inventory":
			for wheel: Node3D in _wheels[id]: wheel.rotation.z = -float(active.t)/150.0
		"laundromat_walkout":
			_sock.rotation.z = visual_ms/190.0
			for index: int in range(_bubbles.size()): _bubbles[index].position = Vector3(-0.31+fmod(index*0.13+visual_ms/8000.0,0.6),1.05+absf(sin(visual_ms/400.0+index))*0.45,0.32)
		"yuri_receipt":
			var anchor: Dictionary = active.anchor; var count: int = int(floor(12*clampf((float(active.t)-3500)/9000,0,1)))
			for index: int in range(_sheets.size()):
				var sheet: Node3D = _sheets[index]; sheet.visible = index < count
				var q: float = index/11.0
				var point := Vector2(lerpf(anchor.x,anchor.tx,q),lerpf(anchor.y,anchor.ty,q)+sin(q*15+visual_ms/240.0)*8)
				sheet.position = Content.to_world(point,1.20+sin(q*PI)*1.1)
				sheet.rotation = Vector3(0.1*sin(visual_ms/300.0+index),sin(q*9)*0.35,0.14*sin(index+visual_ms/430.0))
		"park_dry_committee":
			var anchor: Dictionary = active.anchor; bank.position = Content.to_world(Vector2(anchor.x,anchor.y),0.055)
			var direction := Vector3(cos(active.sprayAngle),0,sin(active.sprayAngle))
			var max_length: float = 6.8
			var world: Node3D = _world_ref.get_ref()
			if float(active.t) < 23000 and world != null and world.is_inside_tree():
				var start: Vector3 = bank.position+Vector3.UP*0.60
				var query := PhysicsRayQueryParameters3D.create(start,start+direction*max_length,1)
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty(): max_length = maxf(0,start.distance_to(hit.position)-0.02)
			for index: int in range(_water.size()):
				var bead: MeshInstance3D = _water[index]; bead.visible = float(active.t) < 23000 and (index+1.0)/24.0*6.8 <= max_length
				var q: float = (index+1.0)/24.0; bead.position = direction*(6.8*q)+Vector3(0,0.60+sin(q*PI)*0.35,0); bead.rotation.y = PI*0.5-active.sprayAngle
			for index: int in range(6):
				var angle: float = -2.8+index*0.52; var bird: Node3D = _pigeons[id][index]
				var point: Vector3 = Content.to_world(Vector2(anchor.x+cos(angle)*78,anchor.y+sin(angle)*48))
				bird.position = Vector3(point.x,_support(point),point.z)-bank.position; bird.rotation.y = -angle-PI*0.5
		"ticketed_luggage":
			for index: int in range(_wheels[id].size()): _wheels[id][index].rotation.x = sin(visual_ms/160.0+index*PI)*0.3
			for index: int in range(3):
				var bird: Node3D = _pigeons[id][index]; bird.visible = float(active.t) > 14000
				bird.position = Vector3((-30-index*26)*0.04,0.01,(8+(index&1)*5)*0.04); bird.rotation.y = PI*0.5
	var elapsed: int = Time.get_ticks_usec()-started; _stats.sync_calls += 1; _stats.sync_usec += elapsed; _stats.max_sync_usec = maxi(_stats.max_sync_usec,elapsed)
	return true
func clear() -> void:
	for bank: Node3D in _banks.values(): bank.visible = false
	_last_id = ""
func metrics() -> Dictionary:
	var result: Dictionary = _stats.duplicate(true); result.ok = _built; result.nodes = _count_nodes(self); result.active_id = _last_id
	result.receipt_sheets = _sheets.size(); result.pigeon_counts = {"park":_pigeons.get("park_dry_committee",[]).size(),"luggage":_pigeons.get("ticketed_luggage",[]).size()}
	return result
func _count_nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children(): total += _count_nodes(child)
	return total
func route_report() -> Dictionary: return _last_route_report.duplicate(true)
func record_route_report(report: Dictionary) -> void: _last_route_report = report.duplicate(true)
func shape_records(view: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []; var active: Variant = view.get("active")
	if not active is Dictionary: return result
	var id: String = active.id
	if ENVELOPES.has(id):
		var size: Vector3 = ENVELOPES[id]
		if id == "runaway_mattress" and active.road.axis == "v": size = Vector3(size.z,size.y,size.x)
		result.append({"id":id,"size":size,"point":Content.to_world(display_point(active),0.055+size.y*0.5)})
	elif id == "park_dry_committee": result.append({"id":"sprinkler","size":Vector3(0.55,0.70,0.55),"point":Content.to_world(Vector2(active.anchor.x,active.anchor.y),0.4)})
	elif id == "yuri_receipt":
		for index: int in range(_sheets.size()):
			if _sheets[index].visible: result.append({"id":"receipt_%d" % index,"size":Vector3(0.60,0.18,0.40),"point":_sheets[index].global_position})
	if _pigeons.has(id):
		for index: int in range(_pigeons[id].size()):
			var bird: Node3D = _pigeons[id][index]
			if bird.visible: result.append({"id":"pigeon_%d" % index,"size":Vector3(0.20,0.36,0.36),"point":bird.global_position+Vector3.UP*0.20})
	return result
func inspect(view: Dictionary,previous: Dictionary = {}) -> Dictionary:
	var world: Node3D = _world_ref.get_ref() if _world_ref != null else null
	if not _built or world == null or not world.is_inside_tree(): return {"ok":false,"reason":"missing_world"}
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var records: Array[Dictionary] = shape_records(view); var old: Array = previous.get("records",[]); var failures: Array[Dictionary] = []
	for index: int in range(records.size()):
		var record: Dictionary = records[index]; var shape := BoxShape3D.new(); shape.size = record.size
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1; query.margin = 0.002
		query.transform = Transform3D(Basis.IDENTITY,record.point)
		for hit: Dictionary in space.intersect_shape(query,16):
			failures.append({"part":record.id,"owner":str(hit.collider.get_meta("source_owner",hit.collider.name)),"point":record.point})
		if index < old.size() and old[index].id == record.id:
			query.transform.origin = old[index].point; query.motion = record.point-old[index].point
			var fractions: PackedFloat32Array = space.cast_motion(query)
			if fractions.size() == 2 and fractions[0] < 0.999999:
				var info: Dictionary = space.get_rest_info(query)
				failures.append({"part":record.id,"owner":"interval_collision","fraction":fractions[0],"point":info.get("point",record.point)})
	return {"ok":failures.is_empty(),"failures":failures,"shapes":records.size(),"records":records}
