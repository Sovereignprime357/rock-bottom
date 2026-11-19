class_name RockBottomActorHudProjection
extends RefCounted
const MAX_ATTEMPTS := 8
static func project(camera: Camera3D,point: Vector3,viewport: Rect2) -> Dictionary:
	if camera == null or not camera.is_inside_tree() or not point.is_finite() or not viewport.position.is_finite() or not viewport.size.is_finite() or minf(viewport.size.x,viewport.size.y) <= 0: return {}
	if not camera.global_transform.is_finite() or absf(camera.global_basis.determinant()) < 0.000001: return {}
	var local: Vector3 = camera.global_transform.affine_inverse()*point
	if not local.is_finite() or -local.z <= camera.near or -local.z >= camera.far or camera.is_position_behind(point): return {}
	var at: Vector2 = camera.unproject_position(point)
	if not at.is_finite() or not viewport.has_point(at): return {}
	return {"point":at,"depth":-local.z}
static func layout(anchor: Vector2,extent: Vector2,viewport: Rect2,occupied: Array[Rect2]) -> Dictionary:
	if not anchor.is_finite() or not extent.is_finite() or minf(extent.x,extent.y) <= 0: return {}
	var top: Vector2 = anchor-Vector2(extent.x*.5,extent.y+8)
	for attempt: int in range(MAX_ATTEMPTS):
		var position: Vector2
		if attempt < 4: position = top-Vector2(0,attempt*(extent.y+2))
		else:
			var right: bool = attempt%2 == 0
			position = Vector2(anchor.x+16 if right else anchor.x-16-extent.x,anchor.y-extent.y*.5 if attempt < 6 else anchor.y+extent.y*.5+4)
		var rect := Rect2(position,extent)
		if not viewport.encloses(rect): continue
		var blocked: bool = false
		for other: Rect2 in occupied:
			if rect.intersects(other): blocked = true; break
		if not blocked: return {"rect":rect,"attempts":attempt+1,"side":attempt >= 4}
	return {}
