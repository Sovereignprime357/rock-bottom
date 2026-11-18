class_name RockBottomGuidanceProjection
extends RefCounted
## Pure presentation geometry. No gameplay owner, scene lookup, clock or ray ownership.
const ARROW := [Vector2(10,0),Vector2(-7,-6),Vector2(-4,0),Vector2(-7,6)]

static func source_style(visual_ms: float) -> Dictionary:
	if not is_finite(visual_ms): return {}
	var pulse: float = (sin(visual_ms/180.0)+1.0)*0.5
	return {"pulse":pulse,"radius":11.0+pulse*3.0,"alpha":0.62+pulse*0.3,"arrow_alpha":1.0,"width":2.0,"arrow":ARROW.duplicate(),"square_size":4.0,"square_offset":Vector2(-2.0,-19.0-pulse*3.0)}

static func _finite_projection(matrix: Projection) -> bool:
	for column: Vector4 in [matrix.x,matrix.y,matrix.z,matrix.w]:
		for value: float in [column.x,column.y,column.z,column.w]:
			if not is_finite(value): return false
	return true

static func project(target: Vector3,camera_transform: Transform3D,camera_projection: Projection,viewport_size: Vector2,safe_rect: Rect2,visual_ms: float,visibility: int = -1) -> Dictionary:
	if not target.is_finite() or not viewport_size.is_finite() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0: return {}
	if not camera_transform.origin.is_finite() or not camera_transform.basis.x.is_finite() or not camera_transform.basis.y.is_finite() or not camera_transform.basis.z.is_finite(): return {}
	if absf(camera_transform.basis.determinant()) <= 0.00000001 or not _finite_projection(camera_projection): return {}
	if absf(camera_projection.determinant()) <= 0.000000000001: return {}
	if not safe_rect.position.is_finite() or not safe_rect.size.is_finite() or safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0: return {}
	var safe: Rect2 = safe_rect.intersection(Rect2(Vector2.ZERO,viewport_size))
	if safe.size.x <= 20.0 or safe.size.y <= 20.0: return {}
	var style: Dictionary = source_style(visual_ms)
	if style.is_empty(): return {}
	var local: Vector3 = camera_transform.affine_inverse()*target
	if local.length_squared() <= 0.00000001: return {}
	var clip: Vector4 = camera_projection*Vector4(local.x,local.y,local.z,1.0)
	var center: Vector2 = viewport_size*0.5
	var point: Vector2; var direction: Vector2; var in_depth: bool = false
	var behind: bool = local.z >= -0.00001 or clip.w <= 0.00001
	if behind:
		# Dividing by a negative clip.w mirrors the wrong side of a turn. Preserve
		# left/right and choose bottom for a directly-behind horizontal target.
		direction = Vector2(local.x,maxf(absf(local.z),0.001))
		direction = direction.normalized(); point = center+direction*viewport_size.length()*2.0
	else:
		var ndc: Vector3 = Vector3(clip.x/clip.w,clip.y/clip.w,clip.z/clip.w)
		if not ndc.is_finite(): return {}
		point = Vector2((ndc.x+1.0)*0.5*viewport_size.x,(1.0-ndc.y)*0.5*viewport_size.y)
		direction = point-center
		in_depth = ndc.z >= -1.0 and ndc.z <= 1.0
		if direction.length_squared() <= 0.00000001: direction = Vector2(0,-1)
	if not point.is_finite() or not direction.is_finite(): return {}
	var ring: bool = not behind and in_depth and point.x > safe.position.x and point.x < safe.end.x and point.y > safe.position.y and point.y < safe.end.y
	# A near/far center point has no usable screen edge until a deterministic
	# direction is selected; keep every arrow on a safe edge, not at center.
	if not ring and safe.has_point(point): point = center+direction.normalized()*viewport_size.length()*2.0
	style["kind"] = "ring" if ring else "arrow"
	style["center"] = point if ring else point.clamp(safe.position,safe.end)
	style["angle"] = atan2(direction.y,direction.x)
	style["behind"] = behind
	style["occluded"] = visibility == 0
	style["dashed"] = visibility == 0
	style["square"] = ring and visibility == 1
	style["square_position"] = Vector2(floor(point.x-2.0+0.5),floor(point.y-float(style.radius)-8.0+0.5))
	if visibility == 0: style.alpha *= 0.45; style.arrow_alpha = 0.45
	return style
