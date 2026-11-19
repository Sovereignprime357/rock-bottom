class_name RockBottomDistrictBorderView
extends Control
## Source border timing is a pure calculation; this Control owns only its outline.
const COLORS := {"street":"#a04848","scrap":"#c08038","spiritual":"#d8c068"}
const PALETTE := ["","#888","#888888","#a04848","#c08038","#d8c068"]
var _remaining_ms: float = 0.0
var _color: String = "#888"
var _alpha: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true; visible = false
	resized.connect(queue_redraw)

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func advance(previous: Dictionary,territory_zone_id: Variant,current_zone: Dictionary,delta_ms: float) -> Dictionary:
	if not is_finite(delta_ms) or delta_ms < 0 or (territory_zone_id != null and not territory_zone_id is String): return {}
	var last: Variant = previous.get("lastZoneId")
	var timer: Variant = previous.get("borderGlowT",0)
	var color: Variant = previous.get("borderGlowColor","")
	var rect: Variant = previous.get("borderGlowRect",{})
	if (last != null and not last is String) or not _number(timer) or not color is String or not rect is Dictionary: return {}
	if not current_zone.is_empty():
		if not current_zone.get("id") is String or not current_zone.get("faction","") is String: return {}
		for key: String in ["x","y","w","h"]:
			if not _number(current_zone.get(key)): return {}
	var result := {"borderGlowT":float(timer),"borderGlowColor":color,"borderGlowRect":rect.duplicate(true),"lastZoneId":last}
	if result.borderGlowT > 0: result.borderGlowT = maxf(0.0,float(result.borderGlowT)-delta_ms)
	if last != territory_zone_id:
		if not current_zone.is_empty() and last != null and current_zone.id != last:
			result.borderGlowT = 600.0
			result.borderGlowColor = COLORS.get(current_zone.get("faction",""),"#888")
			result.borderGlowRect = {"x":current_zone.x,"y":current_zone.y,"w":current_zone.w,"h":current_zone.h}
		result.lastZoneId = territory_zone_id
	return result

func sync(snapshot: Dictionary) -> bool:
	if not _number(snapshot.get("remaining_ms")) or not snapshot.get("color") is String or not snapshot.get("visible") is bool or not PALETTE.has(snapshot.color):
		clear(); return false
	var remaining: float = snapshot.remaining_ms
	var color: String = snapshot.color if not snapshot.color.is_empty() else "#888"
	var alpha: float = minf(0.55,remaining/600.0*0.55) if remaining > 0 and snapshot.visible else 0.0
	var redraw: bool = _alpha != alpha or _color != color
	_remaining_ms = remaining; _color = color; _alpha = alpha
	if visible != (alpha > 0): visible = alpha > 0
	if redraw: queue_redraw()
	return true

func clear() -> void:
	_remaining_ms = 0.0; _alpha = 0.0
	if visible: visible = false

func inspect() -> Dictionary:
	return {"remaining_ms":_remaining_ms,"color":_color,"alpha":_alpha,"width":3.0,"visible":visible}

func _draw() -> void:
	if _alpha <= 0 or size.x <= 3 or size.y <= 3: return
	var color := Color(_color); color.a = _alpha
	draw_rect(Rect2(Vector2(1.5,1.5),size-Vector2(3,3)),color,false,3.0)
