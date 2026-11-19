class_name RockBottomActorHudOverlay
extends Control
## One read-only CanvasItem. Scene supplies actual rig anchors and fresh wall rays.
const View = preload("res://scripts/actor_hud_view.gd")
const ProjectionHelper = preload("res://scripts/actor_hud_projection.gd")
const MAX_RAYS := 64
const SCALE := 1.5
const METRIC_LIMIT := 256
var _view: RefCounted
var _camera_ref: WeakRef
var _anchor: Callable
var _sight: Callable
var _binding_serial: int = 0
var _regular: SystemFont
var _bold: SystemFont
var _vignette: GradientTexture2D
var _metrics: Dictionary = {}
var _metric_order: Array[String] = []
var _clusters: Array[Dictionary] = []
var _combat: Dictionary = {}
var _status_boxes: Dictionary = {}
var _counters: Dictionary = {}
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_regular = SystemFont.new(); _regular.font_names = PackedStringArray(["Courier New","Liberation Mono","monospace"])
	_bold = SystemFont.new(); _bold.font_names = _regular.font_names; _bold.font_weight = 700
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,150.0/460.0,1.0])
	gradient.colors = PackedColorArray([Color(160.0/255,40.0/255,40.0/255,0),Color(160.0/255,40.0/255,40.0/255,0),Color(160.0/255,40.0/255,40.0/255,1)])
	_vignette = GradientTexture2D.new(); _vignette.width = 256; _vignette.height = 256
	_vignette.gradient = gradient; _vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(.5,.5); _vignette.fill_to = Vector2(1,.5)
	_reset_counters()
func _reset_counters() -> void:
	_counters = {"candidates":0,"rays":0,"occluded":0,"excess":0,"offscreen":0,"invalid":0,"layout_hidden":0,"drawn":0,"max_layout_attempts":0,"status_hidden":0}
func bind_model(state: RefCounted,camera: Camera3D,anchor_callback: Callable,visibility_callback: Callable) -> bool:
	clear()
	if state == null or not is_instance_valid(camera) or not anchor_callback.is_valid() or not visibility_callback.is_valid(): return false
	_view = View.new(state); _camera_ref = weakref(camera); _anchor = anchor_callback; _sight = visibility_callback
	return true
func clear() -> void:
	_binding_serial += 1; _view = null; _camera_ref = null; _anchor = Callable(); _sight = Callable()
	_clusters.clear(); _combat.clear(); _status_boxes.clear(); _reset_counters(); queue_redraw()
func _current(serial: int) -> bool:
	return serial == _binding_serial and _view != null and _view.is_current()
func _invalidate_frame() -> bool:
	_clusters.clear(); _combat.clear(); _status_boxes.clear(); queue_redraw(); return false
func _width(text: String,pixels: int,bold: bool = false) -> float:
	var key: String = str(pixels)+("b:" if bold else "r:")+text
	if _metrics.has(key): return _metrics[key]
	var font: Font = _bold if bold else _regular
	var result: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	if _metrics.size() >= METRIC_LIMIT: _metrics.erase(_metric_order.pop_front())
	_metrics[key] = result; _metric_order.append(key); return result
func _cluster_geometry(row: Dictionary,bounds: Rect2) -> Dictionary:
	var width: float = 40; var height: float = 0
	var line_height: float = ceil(_regular.get_height(14))+2
	var chatter_height: float = ceil(_regular.get_height(14))+6
	if not row.chatter.is_empty(): width = maxf(width,_width(row.chatter,14)+12); height += chatter_height+5
	for line: String in row.name_lines: width = maxf(width,_width(line,14)+12); height += line_height
	if not row.hp.is_empty(): width = maxf(width,row.source_width*SCALE+4); height += 9
	var cue_top: float = height
	var cue_height: float = 0
	var cue_origin: float = 0
	var glyphs: Array[Dictionary] = []
	var has_cue: bool = not row.markers.is_empty() or not row.windup.is_empty() or not row.cooldown.is_empty()
	if has_cue:
		var minimum: float = -8; var maximum: float = 8
		for marker: Dictionary in row.markers:
			var pixels: int = int(ceil(marker.font_px*SCALE)); var font: Font = _bold if marker.bold else _regular
			var glyph_width: float = _width(marker.text,pixels,marker.bold)
			var shadow: float = 1 if marker.kind == "floater" else 0
			var left: float = marker.x*SCALE-glyph_width*.5
			var top: float = marker.y*SCALE-font.get_ascent(pixels)
			var bottom: float = marker.y*SCALE+font.get_descent(pixels)+shadow
			width = maxf(width,maxf(absf(left),absf(left+glyph_width+shadow))*2+8)
			minimum = minf(minimum,top); maximum = maxf(maximum,bottom)
			glyphs.append({"marker":marker,"pixels":pixels,"width":glyph_width,"left":left,"top":top,"bottom":bottom,"shadow":shadow})
		cue_origin = height-minimum+4; cue_height = maximum-minimum+8; height += cue_height
	# Layout uses float32 Vector2/Rect2 values. Round the measured union outward
	# so the last baseline/plate cannot extend a few ulps past its certificate.
	width = minf(ceil(width),floor(bounds.size.x)); height = ceil(height)
	var draw_bounds: Array[Rect2] = []
	var y: float = 0
	if not row.chatter.is_empty(): draw_bounds.append(Rect2(0,y,width,chatter_height+5)); y += chatter_height+5
	for _line: String in row.name_lines: draw_bounds.append(Rect2(0,y,width,line_height)); y += line_height
	if not row.hp.is_empty(): draw_bounds.append(Rect2(1,y+1,width-2,7)); y += 9
	if has_cue:
		if not row.windup.is_empty() or not row.cooldown.is_empty(): draw_bounds.append(Rect2(0,cue_top,width,cue_height))
		for glyph: Dictionary in glyphs:
			glyph.position = Vector2(width*.5+glyph.left,cue_origin+glyph.marker.y*SCALE)
			draw_bounds.append(Rect2(width*.5+glyph.left,cue_origin+glyph.top,glyph.width+glyph.shadow,glyph.bottom-glyph.top))
	return {"extent":Vector2(width,height),"line_height":line_height,"chatter_height":chatter_height,"cue_top":cue_top,"cue_height":cue_height,"glyphs":glyphs,"draw_bounds":draw_bounds}
func _status_box(rect: Rect2,bounds: Rect2,occupied: Array[Rect2],direction: float) -> Rect2:
	for index: int in range(ProjectionHelper.MAX_ATTEMPTS):
		var trial := Rect2(rect.position+Vector2(0,index*(rect.size.y+4)*direction),rect.size)
		if not bounds.encloses(trial): continue
		var blocked: bool = false
		for other: Rect2 in occupied:
			if trial.intersects(other): blocked = true; break
		if not blocked: occupied.append(trial); return trial
	_counters.status_hidden += 1; return Rect2()
func _reserve_status(bounds: Rect2,occupied: Array[Rect2]) -> void:
	_status_boxes.clear()
	var center: float = bounds.get_center().x
	if not _combat.get("boss",{}).is_empty():
		var width: float = minf(480,bounds.size.x)
		_status_boxes.boss = _status_box(Rect2(center-width*.5,bounds.position.y+8,width,48),bounds,occupied,1)
	if not _combat.get("stun_text","").is_empty(): _status_boxes.stun = _status_box(Rect2(center-80,bounds.position.y+60,160,28),bounds,occupied,1)
	if not _combat.get("combo",{}).is_empty():
		var pixels: int = clampi(int(ceil(_combat.combo.font_px*SCALE)),1,144)
		var width: float = minf(bounds.size.x,maxf(70,_width(_combat.combo.text,pixels,true)+8))
		_status_boxes.combo = _status_box(Rect2(center-width*.5,bounds.end.y-130,width,pixels+25),bounds,occupied,-1)
func update_frame(visual_ms: float,occupied_rects: Array[Rect2] = []) -> bool:
	_clusters.clear(); _combat.clear(); _status_boxes.clear(); _reset_counters()
	if _view == null or not is_finite(visual_ms) or visual_ms < 0 or size.x <= 24 or size.y <= 24: return _invalidate_frame()
	var serial: int = _binding_serial
	var snapshot: Dictionary = _view.snapshot(visual_ms)
	if snapshot.is_empty(): return _invalidate_frame()
	_combat = snapshot.combat
	var occupied: Array[Rect2] = []
	for rect: Rect2 in occupied_rects:
		if rect.position.is_finite() and rect.size.is_finite() and rect.has_area(): occupied.append(rect)
	var bounds := Rect2(Vector2(12,12),size-Vector2(24,24))
	_reserve_status(bounds,occupied)
	# World cues pause under a modal; source status pulses remain visible beneath it.
	if snapshot.mode != "playing": queue_redraw(); return true
	var camera: Camera3D = _camera_ref.get_ref() if _camera_ref != null else null
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not _anchor.is_valid() or not _sight.is_valid(): return _invalidate_frame()
	var candidates: Array[Dictionary] = []
	for row: Dictionary in snapshot.actors:
		if not row.show_name and row.hp.is_empty() and row.markers.is_empty() and row.chatter.is_empty() and row.windup.is_empty() and row.cooldown.is_empty(): continue
		var anchor: Variant = _anchor.call(row.id)
		if not _current(serial) or not is_instance_valid(camera): return _invalidate_frame()
		if not anchor is Vector3 or not anchor.is_finite(): _counters.invalid += 1; continue
		var projected: Dictionary = ProjectionHelper.project(camera,anchor,Rect2(Vector2.ZERO,size))
		if projected.is_empty(): _counters.offscreen += 1; continue
		candidates.append({"row":row,"anchor":anchor,"point":projected.point,"order":candidates.size()})
	_counters.candidates = candidates.size()
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.row.priority != b.row.priority: return a.row.priority < b.row.priority
		if a.row.distance_squared != b.row.distance_squared: return a.row.distance_squared < b.row.distance_squared
		return a.order < b.order)
	for candidate: Dictionary in candidates:
		if _counters.rays >= MAX_RAYS: _counters.excess += 1; continue
		_counters.rays += 1
		var visible_now: Variant = _sight.call(candidate.row.id,candidate.anchor)
		if not _current(serial) or not is_instance_valid(camera) or not camera.is_inside_tree(): return _invalidate_frame()
		if not visible_now is bool or not visible_now: _counters.occluded += 1; continue
		var geometry: Dictionary = _cluster_geometry(candidate.row,bounds)
		var placement: Dictionary = ProjectionHelper.layout(candidate.point,geometry.extent,bounds,occupied)
		if placement.is_empty(): _counters.layout_hidden += 1; _counters.max_layout_attempts = ProjectionHelper.MAX_ATTEMPTS; continue
		_counters.max_layout_attempts = maxi(_counters.max_layout_attempts,placement.attempts)
		occupied.append(placement.rect); _clusters.append({"facts":candidate.row,"rect":placement.rect,"geometry":geometry,"anchor":candidate.point,"side":placement.side})
	_counters.drawn = _clusters.size(); queue_redraw(); return true
func inspect() -> Dictionary:
	return {"counters":_counters.duplicate(true),"clusters":_clusters.duplicate(true),"combat":_combat.duplicate(true),"status_boxes":_status_boxes.duplicate(true),"metric_cache":_metrics.size(),"resource_ids":[_regular.get_instance_id(),_bold.get_instance_id(),_vignette.get_instance_id()]}
func _color(value: String,alpha: float = 1) -> Color:
	var color := Color.from_string(value,Color("#d4c896")); color.a *= clampf(alpha,0,1); return color
func _text(text: String,at: Vector2,pixels: int,color: Color,bold: bool = false,width: float = -1) -> void:
	var font: Font = _bold if bold else _regular
	var fitted: String = text
	if width >= 0 and _width(text,pixels,bold) > width:
		# Clipping is presentation-only; facts retain the complete source sentence.
		var low: int = 0; var high: int = text.length()
		while low < high:
			var middle: int = floori((low+high+1)*.5)
			if font.get_string_size(text.substr(0,middle),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x <= width: low = middle
			else: high = middle-1
		fitted = text.substr(0,low)
	draw_string(font,at,fitted,HORIZONTAL_ALIGNMENT_CENTER,width,pixels,color)
func _draw_cluster(cluster: Dictionary) -> void:
	var row: Dictionary = cluster.facts; var rect: Rect2 = cluster.rect; var y: float = rect.position.y
	var geometry: Dictionary = cluster.geometry
	if cluster.side:
		var anchor: Vector2 = cluster.anchor
		var edge: Vector2 = anchor.clamp(rect.position,rect.end)
		draw_line(edge,anchor,Color(0.83,0.78,0.59,.48),1,true); draw_circle(anchor,1.5,Color(0.83,0.78,0.59,.58))
	if not row.chatter.is_empty():
		var bubble := Rect2(rect.position,Vector2(rect.size.x,geometry.chatter_height))
		draw_rect(bubble,Color(0,0,0,.85)); draw_rect(bubble.grow(-.5),Color("#665"),false,1)
		_text(row.chatter,bubble.position+Vector2(4,_regular.get_ascent(14)+3),14,Color("#d4c896"),false,bubble.size.x-8)
		draw_colored_polygon(PackedVector2Array([Vector2(rect.get_center().x-3,bubble.end.y),Vector2(rect.get_center().x+3,bubble.end.y),Vector2(rect.get_center().x,bubble.end.y+5)]),Color(0,0,0,.85)); y += geometry.chatter_height+5
	for line: String in row.name_lines:
		draw_rect(Rect2(rect.position.x,y,rect.size.x,geometry.line_height),Color(10.0/255,8.0/255,5.0/255,.76))
		_text(line,Vector2(rect.position.x+4,y+_regular.get_ascent(14)+1),14,Color(row.name_color),false,rect.size.x-8); y += geometry.line_height
	if not row.hp.is_empty():
		var bar := Rect2(rect.position.x+2,y+2,rect.size.x-4,5)
		draw_rect(bar.grow(1),Color.BLACK); draw_rect(bar,Color("#220"))
		draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(row.hp.ratio,0,1),bar.size.y)),Color(row.hp.color)); y += 9
	if not row.markers.is_empty() or not row.windup.is_empty() or not row.cooldown.is_empty():
		var cue := Rect2(rect.position.x,y,rect.size.x,geometry.cue_height)
		for effect: Dictionary in [row.windup,row.cooldown]:
			if not effect.is_empty(): draw_rect(cue,_color(effect.color,effect.alpha))
		for glyph: Dictionary in geometry.glyphs:
			var marker: Dictionary = glyph.marker; var pixels: int = glyph.pixels
			var at: Vector2 = rect.position+glyph.position; var width: float = glyph.width
			if marker.kind == "floater": _text(marker.text,at+Vector2.ONE,pixels,_color("#0a0805",marker.alpha),marker.bold,width)
			_text(marker.text,at,pixels,_color(marker.color,marker.alpha),marker.bold,width)
func _veil(color: Color) -> void:
	if color.a > 0: draw_rect(Rect2(Vector2.ZERO,size),color)
func _draw() -> void:
	for cluster: Dictionary in _clusters: _draw_cluster(cluster)
	if _combat.is_empty(): return
	_veil(_color(_combat.flash_color,_combat.flash))
	# Existing FullHUD owns the scoped high/crash treatment: do not double tint it.
	if _combat.stun > 0:
		var red: Color = _color("#d04040",_combat.stun)
		for edge: Rect2 in [Rect2(0,0,size.x,8),Rect2(0,size.y-8,size.x,8),Rect2(0,0,8,size.y),Rect2(size.x-8,0,8,size.y)]: draw_rect(edge,red)
		var stun: Rect2 = _status_boxes.get("stun",Rect2())
		if stun.has_area(): _text(_combat.stun_text,stun.position+Vector2(0,23),27,Color("#fff080"),true,stun.size.x)
	_veil(_color("#a0c8f0",_combat.slow)); _veil(_color("#a02828",_combat.low_hp))
	var boss: Rect2 = _status_boxes.get("boss",Rect2())
	if boss.has_area():
		draw_rect(boss,Color(0,0,0,.7)); draw_rect(boss,Color("#8a3a3a"),false,2)
		_text(_combat.boss.text,boss.position+Vector2(6,22),18,Color("#d4c896"),true,boss.size.x-12)
		draw_rect(Rect2(boss.position+Vector2(15,30),Vector2((boss.size.x-30)*clampf(_combat.boss.ratio,0,1),12)),Color("#8a3a3a"))
	var combo: Rect2 = _status_boxes.get("combo",Rect2())
	if combo.has_area():
		var pixels: int = clampi(int(ceil(_combat.combo.font_px*SCALE)),1,144); var gold: Color = _color("#e8c040",_combat.combo.alpha)
		_text(_combat.combo.text,combo.position+Vector2(0,pixels),pixels,gold,true,combo.size.x)
		_text(_combat.combo.label,combo.position+Vector2(0,pixels+18),15,gold,false,combo.size.x)
	if _combat.vignette > 0: draw_texture_rect(_vignette,Rect2(Vector2.ZERO,size),false,Color(1,1,1,clampf(_combat.vignette,0,1)))
	_veil(_color("#d488d4",_combat.shakes))
