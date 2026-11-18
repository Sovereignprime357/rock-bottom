class_name RockBottomActorNavigation
extends RefCounted
## Geometry-only bounded local steering; actual physics remains the movement authority.
const SCALE := 0.04
const SOURCE_ORIGIN := Vector2(1050.0,840.0)
const FEET_M := 0.06
const MARGIN_PX := 0.002 / SCALE
const CORNER_PX := 0.0004 / SCALE
const EPSILON := 0.0025
const BUCKET_PX := 200.0
const TARGET_DRIFT_PX := 48.0
const MAX_STARTS := 4
const MAX_TESTS := 192
const SOFT_BUDGET_US := 1000
const MAX_COLLIDERS := 16
const MAX_CORNERS := 64
const REGION_PX := 1600.0
const MAX_QUEUE := 128
const MAX_ACTORS := 256
const EXPIRE_MS := 10000.0
const RETRY_MS := 250.0
const NO_PROGRESS_MS := 500.0
const PAIRS := [[0,1],[1,0],[3,2],[2,3],[0,3],[3,0],[1,2],[2,1]]

var _bounds: Rect2
var _records: Array[Dictionary] = []
var _buckets: Dictionary = {}
var _actors: Dictionary = {}
var _jobs: Dictionary = {}
var _queue: Array[String] = []
var _revision: int = 0
var _frame: int = -1
var _active_ms: float = 0.0
var _frame_tests: int = 0
var _frame_starts: int = 0
var _frame_costs := PackedInt64Array()
var _totals: Dictionary = {"requests":0,"completed":0,"failed":0,"deferred":0,"cache_hits":0,"max_tests":0,"max_starts":0,"max_queue":0,"max_wait_ms":0.0,"max_completion_ms":0.0,"max_plan_us":0,"index_us":0,"geometry_candidates":0}


func _init(world_bounds_px: Rect2 = Rect2(0,0,8600,5600)) -> void:
	_bounds = world_bounds_px


func _decode_records(records: Array) -> Variant:
	var decoded: Array[Dictionary] = []
	for index: int in range(records.size()):
		if not records[index] is Dictionary: return null
		var record: Dictionary = records[index]
		if not record.get("bounds") is AABB or not record.get("owner") is String: return null
		var box: AABB = record.bounds
		if not box.position.is_finite() or not box.size.is_finite() or box.size.x < 0 or box.size.y < 0 or box.size.z < 0: return null
		if record.get("enabled",true) != true or box.end.y <= FEET_M or box.size.x <= 0 or box.size.z <= 0: continue
		decoded.append({"id":str(record.get("id",str(record.owner)+"/"+str(index))),"owner":str(record.owner),
			"rect":Rect2(Vector2(box.position.x,box.position.z)/SCALE+SOURCE_ORIGIN,Vector2(box.size.x,box.size.z)/SCALE),"low":box.position.y,"high":box.end.y})
	return decoded


func set_obstacles(records: Array) -> bool:
	var decoded: Variant = _decode_records(records)
	if not decoded is Array: return false
	_records.assign(decoded)
	_reindex()
	return true


func update_obstacles(owner: String, records: Array) -> bool:
	if owner.is_empty(): return false
	for record: Variant in records:
		if not record is Dictionary or record.get("owner") != owner: return false
	var decoded: Variant = _decode_records(records)
	if not decoded is Array: return false
	var kept: Array[Dictionary] = []
	for record: Dictionary in _records:
		if record.owner != owner: kept.append(record)
	kept.append_array(decoded)
	_records = kept
	_reindex()
	return true


func _reindex() -> void:
	var started: int = Time.get_ticks_usec()
	_buckets.clear()
	for index: int in range(_records.size()):
		var rect: Rect2 = _records[index].rect
		for y: int in range(floori(rect.position.y/BUCKET_PX),floori(rect.end.y/BUCKET_PX)+1):
			for x: int in range(floori(rect.position.x/BUCKET_PX),floori(rect.end.x/BUCKET_PX)+1):
				var cell := Vector2i(x,y)
				if not _buckets.has(cell): _buckets[cell] = []
				_buckets[cell].append(index)
	_totals.index_us = Time.get_ticks_usec()-started
	_invalidate_all()


func reset() -> void:
	_invalidate_all()
	_active_ms = 0.0 # A fresh/loaded Runtime starts a new active-time epoch.
	# Do not reset per-render-frame work allowance during a load/topology change.


func _invalidate_all() -> void:
	_revision += 1
	_actors.clear(); _jobs.clear(); _queue.clear()


func invalidate_actor(id: String) -> void:
	_actors.erase(id); _jobs.erase(id); _queue.erase(id)


func _valid_body(body: Dictionary, height: float) -> bool:
	if not body.get("id") is String or str(body.id).is_empty() or not is_finite(height) or height <= 0.05: return false
	for key: String in ["x","y","w","h"]:
		if not (body.get(key) is int or body.get(key) is float) or not is_finite(float(body[key])): return false
	return body.w > 0 and body.h > 0 and body.w <= _bounds.size.x and body.h <= _bounds.size.y


func _shape_key(body: Dictionary, height: float) -> Vector3: return Vector3(body.w,body.h,height)
func _position(body: Dictionary) -> Vector2: return Vector2(body.x,body.y)
func _center(body: Dictionary) -> Vector2: return _position(body)+Vector2(body.w,body.h)*0.5


func _entry(body: Dictionary, height: float) -> Dictionary:
	var id: String = body.id
	if _actors.has(id):
		var current: Dictionary = _actors[id]
		if current.shape != _shape_key(body,height) or _position(body).distance_squared_to(current.last_position) > 0.01:
			invalidate_actor(id)
	if not _actors.has(id):
		if _actors.size() >= MAX_ACTORS:
			var oldest_id: String = ""
			var oldest_time: float = INF
			for candidate: String in _actors:
				if _actors[candidate].seen < oldest_time: oldest_id = candidate; oldest_time = _actors[candidate].seen
			invalidate_actor(oldest_id)
		_actors[id] = {"shape":_shape_key(body,height),"last_position":_position(body),"seen":_active_ms,"goal":Vector2.INF,
			"path":PackedVector2Array(),"status":"direct","retry_at":0.0,"progress_at":_active_ms}
	var entry: Dictionary = _actors[id]
	entry.seen = _active_ms
	return entry


func steering(body: Dictionary, intended_px: Vector2, goal_center_px: Variant, height_m: float = 1.8) -> Dictionary:
	if not _valid_body(body,height_m): return {"intended":Vector2.ZERO,"detouring":false,"status":"invalid"}
	if not intended_px.is_finite(): return {"intended":_position(body),"detouring":false,"status":"invalid"}
	var origin: Vector2 = _position(body)
	var direct := {"intended":intended_px,"detouring":false,"status":"direct"}
	if body.id == "player": return direct
	var step: float = origin.distance_to(intended_px)
	if step <= EPSILON: return direct # A zero zone clamp preserves the source's cached path.
	if not goal_center_px is Vector2 or not goal_center_px.is_finite():
		invalidate_actor(body.id)
		return direct
	var entry: Dictionary = _entry(body,height_m)
	if entry.goal.is_finite() and entry.goal.distance_to(goal_center_px) > TARGET_DRIFT_PX:
		invalidate_actor(body.id); entry = _entry(body,height_m)
	entry.goal = goal_center_px if not entry.goal.is_finite() else entry.goal
	var path: PackedVector2Array = entry.path
	while not path.is_empty() and _center(body).distance_to(path[0]) <= EPSILON:
		path.remove_at(0)
	entry.path = path
	if path.is_empty():
		if entry.status == "ready": entry.status = "direct"
		direct.status = entry.status
		return direct
	var delta: Vector2 = path[0]-_center(body)
	var next: Vector2 = origin+delta.normalized()*minf(step,delta.length())
	_totals.cache_hits += 1
	return {"intended":next,"detouring":true,"status":"following"}


func note_motion(body: Dictionary, before_px: Vector2, intended_px: Vector2, result: Dictionary, goal_center_px: Variant, height_m: float = 1.8) -> void:
	if not _valid_body(body,height_m) or body.id == "player" or not before_px.is_finite() or not intended_px.is_finite(): return
	if not result.get("position") is Vector2 or not result.position.is_finite() or not result.get("blocked") is bool: return
	if before_px.distance_to(intended_px) <= EPSILON: return
	if not goal_center_px is Vector2 or not goal_center_px.is_finite(): invalidate_actor(body.id); return
	var entry: Dictionary = _entry(body,height_m)
	entry.last_position = result.position
	entry.seen = _active_ms
	if before_px.distance_to(result.position) > EPSILON: entry.progress_at = _active_ms
	elif not entry.path.is_empty() and _active_ms-entry.progress_at > NO_PROGRESS_MS:
		entry.path = PackedVector2Array(); entry.status = "stalled"; entry.retry_at = _active_ms+RETRY_MS
	if not result.blocked: return
	if not entry.path.is_empty(): entry.path = PackedVector2Array(); entry.status = "blocked"
	if _jobs.has(body.id) or _active_ms < float(entry.retry_at): return
	if _queue.size() >= MAX_QUEUE:
		entry.status = "queue_full"; entry.retry_at = _active_ms+RETRY_MS; _totals.deferred += 1
		return
	var start: Vector2 = before_px+Vector2(body.w,body.h)*0.5
	var intended: Vector2 = intended_px+Vector2(body.w,body.h)*0.5
	entry.goal = goal_center_px
	_jobs[body.id] = {"id":str(body.id),"shape":_shape_key(body,height_m),"start":start,"intended":intended,"goal":goal_center_px,
		"queued":_active_ms,"started":false,"phase":"blocker","revision":_revision,"candidate":0,"leg":0,
		"best":PackedVector2Array(),"best_score":INF,"encountered":[],"grow_cursor":0,"nodes":PackedVector2Array(),"edge":0,"limited":false}
	_queue.append(body.id); entry.status = "queued"; _totals.requests += 1
	_totals.max_queue = maxi(_totals.max_queue,_queue.size())


func begin_frame(frame_serial: int, active_ms: float) -> void:
	if frame_serial < 0 or not is_finite(active_ms) or active_ms < _active_ms: return
	_active_ms = active_ms
	if frame_serial <= _frame: return
	_frame = frame_serial; _frame_tests = 0; _frame_starts = 0
	var started: int = Time.get_ticks_usec()
	for id: String in _actors.keys():
		if _active_ms-float(_actors[id].seen) > EXPIRE_MS: invalidate_actor(id)
	var skipped: int = 0
	while not _queue.is_empty() and _frame_tests < MAX_TESTS:
		if Time.get_ticks_usec()-started >= SOFT_BUDGET_US: break
		var id: String = _queue.pop_front()
		if not _jobs.has(id): continue
		var job: Dictionary = _jobs[id]
		if not _actors.has(id) or job.revision != _revision: _jobs.erase(id); continue
		if not job.started:
			if _frame_starts >= MAX_STARTS:
				_queue.append(id); skipped += 1
				if skipped >= _queue.size(): break
				continue
			job.started = true; _frame_starts += 1
			skipped = 0
			_totals.max_wait_ms = maxf(_totals.max_wait_ms,_active_ms-float(job.queued))
		_work(job)
		if _jobs.has(id): _queue.append(id)
	var cost: int = Time.get_ticks_usec()-started
	_frame_costs.append(cost)
	if _frame_costs.size() > 1200: _frame_costs.remove_at(0)
	_totals.max_tests = maxi(_totals.max_tests,_frame_tests); _totals.max_starts = maxi(_totals.max_starts,_frame_starts)
	_totals.max_plan_us = maxi(_totals.max_plan_us,cost)


func _indices(rect: Rect2) -> Array[int]:
	var seen: Dictionary = {}
	for y: int in range(floori(rect.position.y/BUCKET_PX),floori(rect.end.y/BUCKET_PX)+1):
		for x: int in range(floori(rect.position.x/BUCKET_PX),floori(rect.end.x/BUCKET_PX)+1):
			for index: int in _buckets.get(Vector2i(x,y),[]): seen[index] = true
	var indices: Array[int] = []
	indices.assign(seen.keys()); indices.sort()
	return indices


func _expanded(index: int, shape: Vector3) -> Rect2:
	var rect: Rect2 = _records[index].rect
	var padding := Vector2(shape.x*0.5+MARGIN_PX,shape.y*0.5+MARGIN_PX)
	return Rect2(rect.position-padding,rect.size+padding*2.0)


func _height_matches(index: int, shape: Vector3) -> bool:
	return float(_records[index].low) < FEET_M+shape.z+0.002 and float(_records[index].high) > FEET_M-0.002


func _inside_world(point: Vector2, shape: Vector3) -> bool:
	var half := Vector2(shape.x,shape.y)*0.5
	return point.x >= _bounds.position.x+half.x and point.y >= _bounds.position.y+half.y and point.x <= _bounds.end.x-half.x and point.y <= _bounds.end.y-half.y


static func _segment_entry(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var low: float = 0.0
	var high: float = 1.0
	for axis: int in range(2):
		var origin: float = from[axis]
		var delta: float = to[axis]-origin
		var minimum: float = rect.position[axis]+EPSILON
		var maximum: float = rect.end[axis]-EPSILON
		if absf(delta) <= 0.0000001:
			if origin <= minimum or origin >= maximum: return INF
			continue
		var a: float = (minimum-origin)/delta
		var b: float = (maximum-origin)/delta
		low = maxf(low,minf(a,b)); high = minf(high,maxf(a,b))
		if low >= high: return INF
	return low if low < high else INF


func _hit(from: Vector2, to: Vector2, shape: Vector3) -> Dictionary:
	_frame_tests += 1
	if not _inside_world(from,shape) or not _inside_world(to,shape): return {"index":-2,"entry":0.0}
	var padding := Vector2(shape.x,shape.y)*0.5+Vector2.ONE*MARGIN_PX
	var area := Rect2(from.min(to)-padding,(from-to).abs()+padding*2.0)
	var best: int = -1
	var earliest: float = INF
	for index: int in _indices(area):
		_totals.geometry_candidates += 1
		if not _height_matches(index,shape): continue
		var entry: float = _segment_entry(from,to,_expanded(index,shape))
		if entry < earliest: earliest = entry; best = index
	return {"index":best,"entry":earliest}


func _corners(index: int, shape: Vector3) -> PackedVector2Array:
	var rect: Rect2 = _expanded(index,shape).grow(CORNER_PX)
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])


func _remember(job: Dictionary, index: int) -> void:
	if index < 0 or job.encountered.has(index): return
	if job.encountered.size() < MAX_COLLIDERS: job.encountered.append(index)
	else: job.limited = true


func _work(job: Dictionary) -> void:
	match job.phase:
		"blocker":
			var hit: Dictionary = _hit(job.start,job.intended,job.shape)
			if hit.index < 0: _finish(job,PackedVector2Array(),"no_indexed_blocker"); return
			job.blocker = hit.index; _remember(job,hit.index)
			job.corners = _corners(hit.index,job.shape)
			var middle: Vector2 = (job.start+_records[hit.index].rect.get_center())*0.5
			job.region = Rect2(middle-Vector2.ONE*REGION_PX*0.5,Vector2.ONE*REGION_PX)
			job.phase = "goal"
		"goal":
			if _hit(job.goal,job.goal,job.shape).index != -1: _finish(job,PackedVector2Array(),"goal_blocked"); return
			job.phase = "fast"
		"fast": _fast_work(job)
		"grow": _grow_work(job)
		"graph": _graph_work(job)


func _fast_work(job: Dictionary) -> void:
	if job.candidate >= PAIRS.size():
		if not job.best.is_empty(): _finish(job,job.best,"ready"); return
		job.phase = "grow"; return
	var pair: Array = PAIRS[job.candidate]
	var first: Vector2 = job.corners[pair[0]]
	var second: Vector2 = job.corners[pair[1]]
	if not job.region.has_point(first) or not job.region.has_point(second) or _segment_entry(second,job.goal,_expanded(job.blocker,job.shape)) != INF:
		if not job.region.has_point(first) or not job.region.has_point(second): job.limited = true
		job.candidate += 1; job.leg = 0; return
	var hit: Dictionary = _hit(job.start if job.leg == 0 else first,first if job.leg == 0 else second,job.shape)
	if hit.index != -1:
		_remember(job,hit.index); job.candidate += 1; job.leg = 0; return
	if job.leg == 0: job.leg = 1; return
	var score: float = job.start.distance_to(first)+first.distance_to(second)+second.distance_to(job.goal)
	if score < float(job.best_score): job.best_score = score; job.best = PackedVector2Array([first,second])
	job.candidate += 1; job.leg = 0


func _grow_work(job: Dictionary) -> void:
	if job.grow_cursor < job.encountered.size():
		var index: int = job.encountered[job.grow_cursor]
		job.grow_cursor += 1
		var area: Rect2 = _expanded(index,job.shape).grow(CORNER_PX)
		for candidate: int in _indices(area):
			if not _height_matches(candidate,job.shape): continue
			var rect: Rect2 = _expanded(candidate,job.shape)
			if not area.intersects(rect) or not job.region.intersects(rect): continue
			_remember(job,candidate)
		return
	var nodes := PackedVector2Array([job.start])
	for index: int in job.encountered:
		for corner: Vector2 in _corners(index,job.shape):
			if not job.region.has_point(corner): job.limited = true; continue
			if not _inside_world(corner,job.shape): continue
			var repeated: bool = false
			for prior: Vector2 in nodes:
				if prior.distance_squared_to(corner) < EPSILON*EPSILON: repeated = true; break
			if not repeated and nodes.size() <= MAX_CORNERS: nodes.append(corner)
	job.nodes = nodes
	job.distances = PackedFloat64Array(); job.distances.resize(nodes.size()); job.distances.fill(INF); job.distances[0] = 0.0
	job.parents = PackedInt32Array(); job.parents.resize(nodes.size()); job.parents.fill(-1)
	job.closed = PackedByteArray(); job.closed.resize(nodes.size()); job.closed.fill(0)
	job.current = 0; job.edge = 1; job.phase = "graph"


func _graph_work(job: Dictionary) -> void:
	var current: int = job.current
	if current < 0:
		var best: float = INF
		for index: int in range(job.nodes.size()):
			if job.closed[index] != 0: continue
			var score: float = job.distances[index]+job.nodes[index].distance_to(job.goal)
			if score < best: best = score; current = index
		if current < 0: _finish(job,PackedVector2Array(),"local_limit" if job.limited else "local_unreachable"); return
		job.current = current; job.edge = 0
		if current > 0 and _segment_entry(job.nodes[current],job.goal,_expanded(job.blocker,job.shape)) == INF:
			var reversed := PackedVector2Array()
			var cursor: int = current
			while cursor > 0 and reversed.size() <= MAX_CORNERS:
				reversed.append(job.nodes[cursor]); cursor = job.parents[cursor]
			if cursor != 0: _finish(job,PackedVector2Array(),"invalid_local_chain"); return
			reversed.reverse(); _finish(job,reversed,"ready"); return
	while job.edge < job.nodes.size() and (job.edge == current or job.closed[job.edge] != 0): job.edge += 1
	if job.edge >= job.nodes.size(): job.closed[current] = 1; job.current = -1; return
	var next: int = job.edge
	job.edge += 1
	var distance: float = job.distances[current]+job.nodes[current].distance_to(job.nodes[next])
	if distance >= job.distances[next]: return
	if _hit(job.nodes[current],job.nodes[next],job.shape).index != -1: return
	job.distances[next] = distance; job.parents[next] = current


func _finish(job: Dictionary, path: PackedVector2Array, status: String) -> void:
	_totals.max_completion_ms = maxf(_totals.max_completion_ms,_active_ms-float(job.queued))
	if _actors.has(job.id):
		var entry: Dictionary = _actors[job.id]
		entry.path = path; entry.status = status; entry.progress_at = _active_ms
		if path.is_empty(): entry.retry_at = _active_ms+RETRY_MS; _totals.failed += 1
		else: _totals.completed += 1
	_jobs.erase(job.id)


func metrics() -> Dictionary:
	var result: Dictionary = _totals.duplicate(true)
	var costs: PackedInt64Array = _frame_costs.duplicate(); costs.sort()
	var oldest: float = 0.0
	for job: Dictionary in _jobs.values(): oldest = maxf(oldest,_active_ms-float(job.queued))
	result.merge({"frame":_frame,"frame_tests":_frame_tests,"frame_starts":_frame_starts,"queued":_queue.size(),"oldest_pending_ms":oldest,"actors":_actors.size(),
		"colliders":_records.size(),"buckets":_buckets.size(),"revision":_revision,"sample_frames":costs.size(),
		"planning_p50_us":costs[int(floor((costs.size()-1)*0.50))] if not costs.is_empty() else 0,
		"planning_p95_us":costs[int(floor((costs.size()-1)*0.95))] if not costs.is_empty() else 0,
		"scope":"local planner only; real physics movement and60AI/rig rendering are separately measured"})
	return result


func actor_status(id: String) -> Dictionary:
	if not _actors.has(id): return {"status":"absent","path":PackedVector2Array()}
	var entry: Dictionary = _actors[id]
	return {"status":entry.status,"path":entry.path.duplicate(),"goal":entry.goal,"retry_at":entry.retry_at,"seen":entry.seen}
