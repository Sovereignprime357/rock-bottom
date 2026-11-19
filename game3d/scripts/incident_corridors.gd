class_name RockBottomIncidentCorridors
extends RefCounted
## Ephemeral preflight/reservation bridge. No model state, RNG or wall-clock owner.
const Content = preload("res://scripts/content_catalog.gd")
const Presentation = preload("res://scripts/incident_presentation.gd")
var _paths_ref: WeakRef
var _adapter_ref: WeakRef
var _world_ref: WeakRef
var _serial: int = 0
var _prepared: Dictionary = {}
var _active_id: String = ""
var _active_scene: String = ""
var _last_error: String = ""
var _failed: Dictionary = {}
func _init(paths: RefCounted,adapter: RefCounted,world: Node3D) -> void:
	_paths_ref = weakref(paths); _adapter_ref = weakref(adapter); _world_ref = weakref(world)
func _paths() -> Object: return _paths_ref.get_ref() if _paths_ref != null else null
func _adapter() -> Object: return _adapter_ref.get_ref() if _adapter_ref != null else null
func ready() -> bool:
	var paths: Object = _paths(); var adapter: Object = _adapter(); var world: Object = _world_ref.get_ref()
	if paths == null or adapter == null or world == null: return false
	for method: StringName in [&"ready",&"synchronize_geometry",&"mattress_segments"]:
		if not paths.has_method(method): return false
	for method: StringName in [&"incident_geometry_snapshot",&"reserve_incident_corridor",&"release_incident_corridor"]:
		if not adapter.has_method(method): return false
	return paths.ready()
func _failure(reason: String) -> Dictionary:
	_last_error = reason; return {"ok":false,"reason":reason}
func status() -> Dictionary:
	return {"active":_active_scene,"prepared":not _prepared.is_empty(),"last_error":_last_error}
func _blocked(reason: String,snapshot: Dictionary,candidates: Array) -> Dictionary:
	_failed = {"reason":reason,"revision":snapshot.revision,"player_epoch":snapshot.player_epoch,"state_epoch":snapshot.state_epoch,"candidates":candidates.duplicate(true)}
	return _failure(reason)
func preflight(candidates: Array) -> Dictionary:
	if not ready() or candidates.is_empty() or candidates.size() > 6: return _failure("incident_dependencies_unready")
	if not _active_id.is_empty(): return _failure("incident_already_reserved")
	_prepared.clear()
	var seen: Dictionary = {}
	for value: Variant in candidates:
		if not _candidate_valid(value) or seen.has(value.id): return _failure("invalid_incident_candidate")
		seen[value.id] = true
	var adapter: Object = _adapter(); var snapshot: Dictionary = adapter.incident_geometry_snapshot()
	if snapshot.get("ok") != true: return _failure("incident_geometry_unavailable")
	if not _failed.is_empty() and _failed.revision == snapshot.revision and is_same(_failed.player_epoch,snapshot.player_epoch) and is_same(_failed.state_epoch,snapshot.state_epoch) and _failed.candidates == candidates: return _failure(_failed.reason)
	_failed.clear()
	var synchronized: Dictionary = _paths().synchronize_geometry(snapshot)
	if synchronized.get("ok") != true: return _blocked("incident_geometry_uncertified",snapshot,candidates)
	var plans: Dictionary = {}; var originals: Dictionary = {}
	for value: Variant in candidates:
		var plan: Dictionary = _segments(value)
		if not plan.ok: return _blocked(str(plan.reason),snapshot,candidates)
		var temporary: String = "incident:%d:preflight:%d:%s" % [get_instance_id(),_serial+1,str(value.id)]
		if not adapter.reserve_incident_corridor(temporary,snapshot.revision,plan.segments,snapshot.player_epoch,snapshot.state_epoch): return _blocked("incident_route_obstructed:"+str(value.id),snapshot,candidates)
		if not adapter.release_incident_corridor(temporary): return _failure("incident_preflight_release_failed")
		plans[value.id] = plan.segments.duplicate(true); originals[value.id] = value.duplicate(true)
	var current: Dictionary = adapter.incident_geometry_snapshot()
	if current.get("ok") != true or current.revision != snapshot.revision or not is_same(current.player_epoch,snapshot.player_epoch) or not is_same(current.state_epoch,snapshot.state_epoch): return _failure("incident_geometry_changed")
	_serial += 1
	_prepared = {"token":_serial,"revision":snapshot.revision,"player_epoch":snapshot.player_epoch,"state_epoch":snapshot.state_epoch,"plans":plans,"candidates":originals}
	_last_error = ""
	return {"ok":true,"token":_serial,"revision":snapshot.revision}
func activate(prepared: Dictionary,incident: Dictionary) -> bool:
	if not ready() or _prepared.is_empty() or not _active_id.is_empty() or prepared.get("ok") != true or prepared.get("token") != _prepared.token or prepared.get("revision") != _prepared.revision: return false
	var id: String = str(incident.get("id",""))
	if not _prepared.candidates.has(id) or incident != _prepared.candidates[id]: return false
	var reservation_id: String = "incident:%d:active:%d:%s" % [get_instance_id(),_serial,id]
	if not _adapter().reserve_incident_corridor(reservation_id,_prepared.revision,_prepared.plans[id],_prepared.player_epoch,_prepared.state_epoch): return false
	_active_id = reservation_id; _active_scene = id; _prepared.clear(); return true
func release() -> bool:
	_prepared.clear(); _failed.clear()
	if _active_id.is_empty(): return true
	var adapter: Object = _adapter()
	if adapter == null or not adapter.release_incident_corridor(_active_id): return false
	_active_id = ""; _active_scene = ""; return true
func _segment(a: Vector3,b: Vector3,size: Vector3) -> Dictionary:
	return {"from":a,"to":b,"size":size}
func _finite_fields(record: Dictionary,keys: Array[String]) -> bool:
	for key: String in keys:
		var value: Variant = record.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	return true
func _candidate_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("id","") not in Presentation.IDS or not value.get("actors") is Array: return false
	if value.get("t") != 0 or value.get("beat") != -1 or value.get("bumped") != false: return false
	var durations := {"runaway_mattress":25000,"possum_inventory":30000,"laundromat_walkout":29000,"yuri_receipt":28000,"park_dry_committee":28000,"ticketed_luggage":31000}
	if value.get("duration") != durations[value.id]: return false
	if value.id in ["yuri_receipt","park_dry_committee"]:
		if not value.actors.is_empty() or not value.get("anchor") is Dictionary or not _finite_fields(value.anchor,["x","y"]): return false
		if value.id == "park_dry_committee": return value.anchor.x == 2600 and value.anchor.y == 1280 and value.get("sprayAngle") == -0.4
		if value.anchor.x != 310 or value.anchor.y != 220 or not _finite_fields(value.anchor,["tx","ty"]): return false
		var bounds: Dictionary = Content.load_content().world.bounds
		return value.anchor.tx >= 0 and value.anchor.ty >= 0 and value.anchor.tx <= bounds.w and value.anchor.ty <= bounds.h
	if value.actors.size() != 1 or not value.actors[0] is Dictionary or not _finite_fields(value.actors[0],["x","y"]): return false
	if value.id == "runaway_mattress": return value.get("road") is Dictionary and value.actors[0].get("kind") == "mattress" and _finite_fields(value.actors[0],["sx","sy","ex","ey"])
	var expected := {"possum_inventory":["forklift",720,1515],"laundromat_walkout":["dryer",1540,1190],"ticketed_luggage":["suitcase",360,2985]}
	var start: Array = expected[value.id]; var actor: Dictionary = value.actors[0]
	return actor.get("kind") == start[0] and actor.x == start[1] and actor.y == start[2]
func _support(point: Vector3) -> float:
	var world: Node3D = _world_ref.get_ref()
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.5,point-Vector3.UP*0.1,1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return maxf(0.06,float(hit.position.y)+0.025) if not hit.is_empty() else 0.06
func _segments(incident: Dictionary) -> Dictionary:
	var id: String = incident.id; var segments: Array[Dictionary] = []
	if id == "runaway_mattress": return _paths().mattress_segments(incident)
	if id == "yuri_receipt":
		var anchor: Dictionary = incident.anchor
		# Full wind/rotation envelope covers every possible external visual timestamp.
		for index: int in range(12):
			var q: float = index/11.0
			var point: Vector3 = Content.to_world(Vector2(lerpf(anchor.x,anchor.tx,q),lerpf(anchor.y,anchor.ty,q)),1.20+sin(q*PI)*1.1)
			segments.append(_segment(point,point,Vector3(0.64,0.20,1.08)))
		return {"ok":true,"segments":segments}
	if id == "park_dry_committee":
		var anchor: Dictionary = incident.anchor; var center: Vector3 = Content.to_world(Vector2(anchor.x,anchor.y),0.40)
		segments.append(_segment(center,center,Vector3(0.55,0.70,0.55)))
		for index: int in range(6):
			var angle: float = -2.8+index*0.52
			var point: Vector3 = Content.to_world(Vector2(anchor.x+cos(angle)*78,anchor.y+sin(angle)*48))
			point.y = _support(point)+0.21; segments.append(_segment(point,point,Vector3(0.20,0.38,0.36)))
		return {"ok":true,"segments":segments}
	var duration: float = float(incident.duration)
	var times: Array[float] = [0.0,duration]
	for step: int in range(1,int(ceil(duration/200.0))): times.append(minf(duration,step*200.0))
	var knots: Array[float] = []
	match id:
		"possum_inventory": knots.assign([21000.0,24500.0,220.0*24500.0/620.0])
		"laundromat_walkout": knots.assign([6615.0,9800.0,14700.0,24500.0])
		_: knots.assign([9000.0,14000.0,14500.0,14500.0+(1200.0-670.0)*12500.0/650.0,27000.0])
	for time: float in knots:
		if time > 0 and time < duration and not times.has(time): times.append(time)
	times.sort()
	var size: Vector3 = Presentation.ENVELOPES[id]
	# Analytic interpolation error bounds for200ms source intervals. Source phase
	# and visual-detour corners are inserted above, so no interval crosses a kink.
	size.z += 0.05 if id == "laundromat_walkout" else (0.030 if id == "ticketed_luggage" else 0.024)
	if id == "ticketed_luggage": size.z += 1.12 # Every source player-avoidance offset0..28px.
	for index: int in range(1,times.size()):
		var a: Vector2 = _moving_point(id,times[index-1]); var b: Vector2 = _moving_point(id,times[index])
		var lift: float = 0.56 if id == "ticketed_luggage" else 0.0
		var from: Vector3 = Content.to_world(a,0.055+size.y*0.5)+Vector3(0,0,lift)
		var to: Vector3 = Content.to_world(b,0.055+size.y*0.5)+Vector3(0,0,lift)
		segments.append(_segment(from,to,size))
		if id == "ticketed_luggage" and times[index] > 14000:
			for bird: int in range(3):
				var offset := Vector3((-30-bird*26)*0.04,0.055+0.01+0.21,(8+(bird&1)*5)*0.04+0.56)
				segments.append(_segment(Content.to_world(a)+offset,Content.to_world(b)+offset,Vector3(0.20,0.38,1.510)))
	return {"ok":true,"segments":segments}
func _moving_point(id: String,time: float) -> Vector2:
	var actor: Dictionary = {}
	match id:
		"possum_inventory": actor = {"x":720+minf(1,time/24500.0)*620,"y":1515+sin(time/430.0)*5}
		"laundromat_walkout": actor = {"x":1540+minf(1,time/24500.0)*360,"y":1190+minf(1,time/24500.0)*45+sin(time/170.0)*3}
		"ticketed_luggage": actor = {"x":360+(time/9000.0)*310 if time < 9000 else (670.0 if time < 14500 else 670+minf(1,(time-14500.0)/12500.0)*650),"y":2985+sin(time/260.0)*3}
	return Presentation.display_point({"id":id,"t":time,"actors":[actor]})
