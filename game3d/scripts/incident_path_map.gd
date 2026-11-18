class_name RockBottomIncidentPathMap
extends RefCounted
## Cached geometry only. No clocks, source RNG, model writes or per-frame planning.
const Content = preload("res://scripts/content_catalog.gd")
const MAX_OFFSET := 100.0
const MAX_NODES := 512
const MAX_RECTANGLES := 192
const SIZE := Vector3(1.16,0.38,1.02)
const FEET := 0.055
const SKIN := 0.006
const CORNER_GAP := 0.30
var _world_ref: WeakRef
var _maps: Dictionary = {}
var _ready: bool = false
var _report: Dictionary = {"complete":false,"ok":false,"roads":[]}
var _visibility_checks: int = 0

func ready() -> bool: return _ready and _world_ref != null and _world_ref.get_ref() != null
func report() -> Dictionary: return _report.duplicate(true)
func build(world: Node3D) -> Dictionary:
	if world == null or not world.is_inside_tree() or not world.has_method(&"obstacle_records"):
		return {"complete":false,"ok":false,"reason":"missing_world"}
	_world_ref = weakref(world); _maps.clear(); _ready = false; _visibility_checks = 0
	var started: int = Time.get_ticks_usec(); var roads: Array = Content.load_content().world.roadSegments
	_report = {"complete":false,"ok":false,"roads":[],"failures":[]}
	var obstacles: Array[Dictionary] = world.obstacle_records()
	for road: Dictionary in roads:
		var result: Dictionary = _plan(road,obstacles)
		if result.ok:
			var proof: Dictionary = _certify(result)
			result.physics = proof; result.ok = proof.ok
		if result.ok: _maps[str(road.id)] = result
		else: _report.failures.append(str(road.id)+":"+str(result.get("reason","physical_collision")))
		_report.roads.append(result)
	_ready = _maps.size() == 28 and roads.size() == 28
	_report.complete = true; _report.ok = _ready; _report.build_usec = Time.get_ticks_usec()-started; _report.visibility_checks = _visibility_checks; _report.map_count = _maps.size()
	return report()
func _local(point: Vector2,road: Dictionary) -> Vector2:
	return Vector2(point.x,point.y-(float(road.y)+float(road.h)*0.5)) if road.axis == "h" else Vector2(point.y,point.x-(float(road.x)+float(road.w)*0.5))
func _source(point: Vector2,road: Dictionary) -> Vector2:
	return Vector2(point.x,float(road.y)+float(road.h)*0.5+point.y) if road.axis == "h" else Vector2(float(road.x)+float(road.w)*0.5+point.y,point.x)
func _point_clear(point: Vector2,rectangles: Array[Rect2]) -> bool:
	if absf(point.y) > MAX_OFFSET: return false
	for rect: Rect2 in rectangles:
		if point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y: return false
	return true
func _segment_clear(a: Vector2,b: Vector2,rectangles: Array[Rect2]) -> bool:
	_visibility_checks += 1
	var delta: Vector2 = b-a
	for rect: Rect2 in rectangles:
		if maxf(a.x,b.x) < rect.position.x or minf(a.x,b.x) > rect.end.x or maxf(a.y,b.y) < rect.position.y or minf(a.y,b.y) > rect.end.y: continue
		var entry: float = 0.0; var leave: float = 1.0; var blocked: bool = true
		for axis: int in range(2):
			if absf(delta[axis]) < 0.0000001:
				if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: blocked = false; break
			else:
				var near: float = (rect.position[axis]-a[axis])/delta[axis]; var far: float = (rect.end[axis]-a[axis])/delta[axis]
				entry = maxf(entry,minf(near,far)); leave = minf(leave,maxf(near,far))
				if entry > leave: blocked = false; break
		if blocked: return false
	return true
func _endpoint(u: float,rectangles: Array[Rect2]) -> Array[Vector2]:
	if _point_clear(Vector2(u,0),rectangles): return [Vector2(u,0)]
	var candidates: Array[Vector2] = [Vector2(u,-MAX_OFFSET),Vector2(u,MAX_OFFSET)]
	for rect: Rect2 in rectangles:
		for offset: float in [rect.position.y-CORNER_GAP,rect.end.y+CORNER_GAP]:
			var point := Vector2(u,offset)
			if _point_clear(point,rectangles): candidates.append(point)
	var result: Array[Vector2] = []
	for point: Vector2 in candidates:
		if _point_clear(point,rectangles) and not result.has(point): result.append(point)
	return result
func _plan(road: Dictionary,obstacles: Array[Dictionary]) -> Dictionary:
	var horizontal: bool = road.axis == "h"
	var lo: float = float(road.x if horizontal else road.y)+18.0-(0.0 if horizontal else 3.0)
	var hi: float = float(road.x+road.w if horizontal else road.y+road.h)-18.0+(0.0 if horizontal else 3.0)
	var half_long: float = (SIZE.x*0.5+SKIN)/0.04
	var half_cross: float = (SIZE.z*0.5+SKIN)/0.04+(3.0 if horizontal else 0.0)
	var rectangles: Array[Rect2] = []; var owners: Array[String] = []
	for obstacle: Dictionary in obstacles:
		var bounds: AABB = obstacle.bounds
		if bounds.end.y <= FEET or bounds.position.y >= FEET+SIZE.y: continue
		var a: Vector2 = _local(Content.to_source(bounds.position),road); var b: Vector2 = _local(Content.to_source(bounds.end),road)
		var minimum := Vector2(minf(a.x,b.x)-half_long,minf(a.y,b.y)-half_cross)
		var maximum := Vector2(maxf(a.x,b.x)+half_long,maxf(a.y,b.y)+half_cross)
		if maximum.x < lo or minimum.x > hi or maximum.y < -MAX_OFFSET or minimum.y > MAX_OFFSET: continue
		rectangles.append(Rect2(minimum,maximum-minimum)); owners.append(str(obstacle.owner))
	var result := {"id":road.id,"road":road.duplicate(true),"ok":false,"reason":"","rectangles":rectangles.size(),"owners":owners,"points":PackedVector2Array(),"maximum_offset_px":0.0}
	if rectangles.size() > MAX_RECTANGLES: result.reason = "rectangle_cap"; return result
	var nodes: Array[Vector2] = _endpoint(lo,rectangles); var ends: Array[Vector2] = _endpoint(hi,rectangles)
	if nodes.is_empty() or ends.is_empty(): result.reason = "no_clear_endpoint_within100px"; return result
	nodes.append_array(ends)
	for rect: Rect2 in rectangles:
		for u: float in [rect.position.x-CORNER_GAP,rect.end.x+CORNER_GAP]:
			if u <= lo or u >= hi: continue
			for v: float in [rect.position.y-CORNER_GAP,rect.end.y+CORNER_GAP]:
				var point := Vector2(u,v)
				if _point_clear(point,rectangles) and not nodes.has(point): nodes.append(point)
	if nodes.size() > MAX_NODES: result.reason = "node_cap"; return result
	nodes.sort_custom(func(a: Vector2,b: Vector2): return a.x < b.x if a.x != b.x else a.y < b.y)
	var costs := PackedFloat64Array(); var parents := PackedInt32Array(); costs.resize(nodes.size()); costs.fill(INF); parents.resize(nodes.size()); parents.fill(-1)
	for index: int in range(nodes.size()):
		var point: Vector2 = nodes[index]
		if absf(point.x-lo) < 0.001: costs[index] = absf(point.y)*0.05
		for previous: int in range(index):
			if not is_finite(costs[previous]) or point.x-nodes[previous].x < 0.001: continue
			var cost: float = costs[previous]+point.distance_to(nodes[previous])
			if cost >= costs[index] or not _segment_clear(nodes[previous],point,rectangles): continue
			costs[index] = cost; parents[index] = previous
	var winner: int = -1; var best: float = INF
	for index: int in range(nodes.size()):
		if absf(nodes[index].x-hi) < 0.001 and costs[index]+absf(nodes[index].y)*0.05 < best:
			winner = index; best = costs[index]+absf(nodes[index].y)*0.05
	if winner < 0: result.reason = "no_monotonic_lane_within100px"; return result
	var path := PackedVector2Array()
	while winner >= 0: path.append(nodes[winner]); winner = parents[winner]
	path.reverse()
	for point: Vector2 in path: result.maximum_offset_px = maxf(result.maximum_offset_px,absf(point.y))
	result.ok = true; result.reason = ""; result.points = path; result.nodes = nodes.size(); return result
func _certify(plan: Dictionary) -> Dictionary:
	var world: Node3D = _world_ref.get_ref(); var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var horizontal: bool = plan.road.axis == "h"
	var size: Vector3 = SIZE if horizontal else Vector3(SIZE.z,SIZE.y,SIZE.x)
	if horizontal: size.z += 0.24 # Exact continuous union of the source lateral sine.
	var shape := BoxShape3D.new(); shape.size = size
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1; query.margin = 0.002
	var failures: Array[Dictionary] = []; var path: PackedVector2Array = plan.points
	for index: int in range(path.size()):
		var at: Vector3 = Content.to_world(_source(path[index],plan.road),FEET+SIZE.y*0.5)
		query.transform = Transform3D(Basis.IDENTITY,at); query.motion = Vector3.ZERO
		for hit: Dictionary in space.intersect_shape(query,16): failures.append({"owner":str(hit.collider.get_meta("source_owner",hit.collider.name)),"node":index,"source":_source(path[index],plan.road)})
		if index == path.size()-1: continue
		query.motion = Content.to_world(_source(path[index+1],plan.road),FEET+SIZE.y*0.5)-at
		var fraction: PackedFloat32Array = space.cast_motion(query)
		if fraction.size() == 2 and fraction[0] < 0.999999:
			var point: Vector3 = at+query.motion*minf(1.0,float(fraction[1])+0.00001)
			query.transform.origin = point; query.motion = Vector3.ZERO
			var hits: Array[Dictionary] = space.intersect_shape(query,16)
			for hit: Dictionary in hits: failures.append({"owner":str(hit.collider.get_meta("source_owner",hit.collider.name)),"segment":index,"fraction":fraction[0],"source":Content.to_source(point)})
			if hits.is_empty(): failures.append({"owner":"interval_collision","segment":index,"fraction":fraction[0],"source":Content.to_source(point)})
	return {"ok":failures.is_empty(),"failures":failures,"segments":maxi(0,path.size()-1)}
func map_mattress(incident: Dictionary,source: Vector2) -> Dictionary:
	if not ready() or not source.is_finite() or not incident.get("road") is Dictionary: return {"ok":false,"reason":"unready_map"}
	var id: String = str(incident.road.get("id",""))
	if not _maps.has(id): return {"ok":false,"reason":"unknown_road"}
	var plan: Dictionary = _maps[id]; var path: PackedVector2Array = plan.points; var local: Vector2 = _local(source,plan.road)
	if not _valid_source_point(incident,source,plan.road): return {"ok":false,"reason":"noncanonical_source_point"}
	if local.x < path[0].x-0.001 or local.x > path[-1].x+0.001: return {"ok":false,"reason":"outside_source_trajectory"}
	var offset: float = path[-1].y
	for index: int in range(1,path.size()):
		if local.x <= path[index].x:
			offset = lerpf(path[index-1].y,path[index].y,(local.x-path[index-1].x)/(path[index].x-path[index-1].x)); break
	var point: Vector2 = source+Vector2(0,offset) if plan.road.axis == "h" else source+Vector2(offset,0)
	return {"ok":absf(offset) <= MAX_OFFSET+0.001,"point":point,"offset_px":offset,"road":id}
func _valid_source_point(incident: Dictionary,source: Vector2,road: Dictionary) -> bool:
	if incident.get("id") != "runaway_mattress" or not incident.get("actors") is Array or incident.actors.size() != 1 or not incident.actors[0] is Dictionary: return false
	for key: String in ["id","axis","x","y","w","h"]:
		if incident.road.get(key) != road.get(key): return false
	var actor: Dictionary = incident.actors[0]
	if actor.get("kind") != "mattress": return false
	for key: String in ["sx","sy","ex","ey"]:
		var value: Variant = actor.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	for key: String in ["t","duration"]:
		var value: Variant = incident.get(key)
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if incident.duration != 25000 or incident.t < 0 or incident.t > 25050: return false
	var horizontal: bool = road.axis == "h"
	var center: float = float(road.y)+float(road.h)*0.5 if horizontal else float(road.x)+float(road.w)*0.5
	var low: float = float(road.x if horizontal else road.y)+18.0
	var high: float = float(road.x+road.w if horizontal else road.y+road.h)-18.0
	if horizontal:
		if actor.sy != center or actor.ey != center or actor.sx < low or actor.sx > high or actor.ex < low or actor.ex > high: return false
	elif actor.sx != center or actor.ex != center or actor.sy < low or actor.sy > high or actor.ey < low or actor.ey > high: return false
	var q: float = minf(1.0,float(incident.t)/float(incident.duration)); var ease: float = q*q*(3-2*q)
	var expected := Vector2(actor.sx+(actor.ex-actor.sx)*ease,actor.sy+(actor.ey-actor.sy)*ease+sin(float(incident.t)/240.0)*3)
	return source.distance_to(expected) <= 0.001
