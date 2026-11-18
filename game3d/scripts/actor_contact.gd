class_name RockBottomActorContact
extends RefCounted
## Pure source-footprint geometry. No state ownership, physics, clocks or RNG.

const OVERLAP_PX := 1.0
const EPSILON := 0.002


static func valid(body: Dictionary) -> bool:
	for key: String in ["x","y","w","h"]:
		var value: Variant = body.get(key)
		if not (value is float or value is int) or not is_finite(float(value)): return false
	return float(body.w) > 0.0 and float(body.h) > 0.0


static func center(body: Dictionary, origin: Vector2) -> Vector2:
	return origin+Vector2(float(body.w),float(body.h))*0.5


static func half_extents(body: Dictionary, peer: Dictionary) -> Vector2:
	var full := Vector2(float(body.w)+float(peer.w),float(body.h)+float(peer.h))*0.5
	return full-Vector2(minf(OVERLAP_PX,full.x*0.25),minf(OVERLAP_PX,full.y*0.25))


static func penetrating(body: Dictionary, origin: Vector2, peer: Dictionary) -> bool:
	if not valid(body) or not valid(peer) or not origin.is_finite(): return false
	var delta: Vector2 = center(body,origin)-center(peer,Vector2(peer.x,peer.y))
	var half: Vector2 = half_extents(body,peer)
	return absf(delta.x) < half.x-EPSILON and absf(delta.y) < half.y-EPSILON


static func first_hit(body: Dictionary, origin: Vector2, motion: Vector2, peers: Array[Dictionary]) -> Dictionary:
	if not valid(body) or not origin.is_finite() or not motion.is_finite() or motion.length_squared() <= 0.000000001: return {}
	var best: Dictionary = {}
	for peer: Dictionary in peers:
		if not valid(peer): continue
		var hit: Dictionary = _hit(body,origin,motion,peer)
		if hit.is_empty(): continue
		if best.is_empty() or float(hit.fraction) < float(best.fraction)-0.0000001 or (absf(float(hit.fraction)-float(best.fraction)) <= 0.0000001 and str(hit.peer_id) < str(best.peer_id)):
			best = hit
	return best


static func _hit(body: Dictionary, origin: Vector2, motion: Vector2, peer: Dictionary) -> Dictionary:
	var delta: Vector2 = center(body,origin)-center(peer,Vector2(peer.x,peer.y))
	var half: Vector2 = half_extents(body,peer)
	var normal := Vector2.ZERO
	var fraction: float = 0.0
	if absf(delta.x) < half.x-EPSILON and absf(delta.y) < half.y-EPSILON:
		# Escape an existing penetration on any outward axis. This cannot tunnel
		# into a peer from outside; it is only the deferred-initial-repair case.
		if (absf(motion.x) > EPSILON and delta.x*motion.x >= 0.0) or (absf(motion.y) > EPSILON and delta.y*motion.y >= 0.0): return {}
		var x_first: bool = half.x-absf(delta.x) <= half.y-absf(delta.y)
		var sign_value: float = 1.0 if str(body.get("id","player")) < str(peer.get("id","")) else -1.0
		if x_first: normal = Vector2(signf(delta.x) if delta.x != 0 else sign_value,0)
		else: normal = Vector2(0,signf(delta.y) if delta.y != 0 else sign_value)
	else:
		var enter: float = -INF
		var leave: float = INF
		for axis: int in range(2):
			var velocity: float = motion[axis]
			if absf(velocity) < 0.0000001:
				if absf(delta[axis]) >= half[axis]-EPSILON: return {}
				continue
			var near_t: float = (-half[axis]-delta[axis])/velocity
			var far_t: float = (half[axis]-delta[axis])/velocity
			var entering_normal := Vector2.ZERO
			entering_normal[axis] = -signf(velocity)
			if near_t > far_t:
				var swap: float = near_t; near_t = far_t; far_t = swap
			if near_t > enter:
				enter = near_t; normal = entering_normal
			leave = minf(leave,far_t)
			if enter > leave: return {}
		if leave < 0.0 or enter > 1.0: return {}
		if enter < 0.0:
			# A float32 endpoint can be a fraction of a pixel inside the contact
			# band. Use its nearest face; the old slab entry is the opposite face.
			if half.x-absf(delta.x) <= half.y-absf(delta.y): normal = Vector2(signf(delta.x),0)
			else: normal = Vector2(0,signf(delta.y))
		if motion.dot(normal) >= 0.0: return {}
		fraction = clampf(enter,0.0,1.0)
	return {"fraction":fraction,"normal":normal,"peer_id":str(peer.get("id","")),"neutral":peer.get("neutral",false)}


static func tangent(normal: Vector2, moving_id: String, peer_id: String) -> Vector2:
	var result := Vector2(-normal.y,normal.x)
	return result if moving_id < peer_id else -result


static func repair_candidates(body: Dictionary, origin: Vector2, peers: Array[Dictionary]) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	if not valid(body) or not origin.is_finite(): return candidates
	var at: Vector2 = center(body,origin)
	var closest: Dictionary = {}
	var union_low := Vector2(INF,INF)
	var union_high := Vector2(-INF,-INF)
	for peer: Dictionary in peers:
		if not penetrating(body,origin,peer): continue
		var point: Vector2 = center(peer,Vector2(peer.x,peer.y))
		var half: Vector2 = half_extents(body,peer)
		var low: Vector2 = point-half
		var high: Vector2 = point+half
		union_low = union_low.min(low); union_high = union_high.max(high)
		var distance: float = minf(minf(at.x-low.x,high.x-at.x),minf(at.y-low.y,high.y-at.y))
		if closest.is_empty() or distance < float(closest.distance) or (distance == float(closest.distance) and str(peer.get("id","")) < str(closest.id)):
			closest = {"low":low,"high":high,"distance":distance,"id":str(peer.get("id",""))}
	if closest.is_empty(): return candidates
	var first_sign: float = 1.0 if str(body.get("id","player")) < str(closest.id) else -1.0
	for box: Dictionary in [closest,{"low":union_low,"high":union_high}]:
		for sign_value: float in [first_sign,-first_sign]:
			var candidate: Vector2 = origin+Vector2((box.high.x if sign_value > 0 else box.low.x)-at.x,0)
			if candidate not in candidates: candidates.append(candidate)
		for sign_value: float in [first_sign,-first_sign]:
			var candidate: Vector2 = origin+Vector2(0,(box.high.y if sign_value > 0 else box.low.y)-at.y)
			if candidate not in candidates: candidates.append(candidate)
	# Stable insertion sort preserves the ID-selected direction for equal distance.
	for i: int in range(1,candidates.size()):
		var value: Vector2 = candidates[i]
		var j: int = i-1
		while j >= 0 and origin.distance_squared_to(candidates[j]) > origin.distance_squared_to(value):
			candidates[j+1] = candidates[j]; j -= 1
		candidates[j+1] = value
	return candidates
