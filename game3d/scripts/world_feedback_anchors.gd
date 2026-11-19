extends RefCounted
## Pure, immutable authored-height lookup. Never resolves actor IDs against live state.
const Roster = preload("res://scripts/character_roster.gd")
const Content = preload("res://scripts/content_catalog.gd")
const FALLBACK_HEIGHT := 1.8
var _heights: Dictionary = {}

func _init() -> void:
	for visual: String in Roster.supported_visuals():
		var height: float = float(Roster.definition(StringName(visual)).get("height",FALLBACK_HEIGHT))
		if is_finite(height) and height > 0.0 and height <= 20.0: _heights[visual] = height

func decorate(raw: Dictionary,right: Vector3,epoch: int) -> Dictionary:
	if not raw.get("source_point") is Vector2 or not raw.source_point.is_finite(): return {}
	if not raw.get("recipe") is String or not raw.get("anchor_kind") is String: return {}
	if not right.is_finite() or not is_finite(right.length_squared()) or right.length_squared() < 0.000001: return {}
	var horizontal := Vector3(right.x,0.0,right.z)
	if horizontal.length_squared() < 0.000001: return {}
	horizontal = horizontal.normalized()
	var point: Vector2 = raw.source_point
	var anchor: Vector3
	match raw.anchor_kind:
		"body","head":
			if not raw.get("source_rect") is Rect2: return {}
			var rect: Rect2 = raw.source_rect
			if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0: return {}
			var center: Vector2 = rect.get_center()
			var height: float = FALLBACK_HEIGHT
			if raw.get("source_actor") is Dictionary:
				var visual: StringName = Roster.visual_for_actor(raw.source_actor)
				height = float(_heights.get(String(visual),FALLBACK_HEIGHT))
			var player: bool = raw.get("actor_id","") == "player"
			var vertical: float = 1.0 if player else height*0.55
			var origin_y: float = center.y
			if raw.anchor_kind == "head": vertical = height*0.90; origin_y = rect.position.y
			anchor = Content.to_world(center,vertical)+horizontal*(point.x-center.x)*Content.METRES_PER_PIXEL-Vector3.UP*(point.y-origin_y)*Content.METRES_PER_PIXEL
		"ground": anchor = Content.to_world(point,0.08)
		"projectile": anchor = Content.to_world(point,1.0)
		_: return {}
	if not anchor.is_finite(): return {}
	var result := {"epoch":epoch,"recipe":raw.recipe,"source_point":point,"world_anchor":anchor,"birth_right":horizontal}
	for key: String in ["sings","phase","width"]:
		if raw.has(key): result[key] = raw[key]
	return result

func inspect() -> Dictionary:
	return {"heights":_heights.duplicate(),"fallback_height":FALLBACK_HEIGHT}
