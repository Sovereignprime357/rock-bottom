class_name RockBottomWallMarkingView
extends Node3D
## Read-only source layouts on audited facade panels. No generation, clocks or RNG.
const Content = preload("res://scripts/content_catalog.gd")
const Surface = preload("res://scripts/surface_kit.gd")
const SCALES := [1.0,0.85,0.70,0.55,0.40,0.30,0.22,0.18,0.15]
static var _unit_box: BoxMesh
var _font: SystemFont
var _last: Dictionary = {}
var _surfaces: Array = []
var _records: Array[Dictionary] = []
var _rejected: Array[Dictionary] = []
var _builds: int = 0
var _requested: int = 0

static func create() -> RockBottomWallMarkingView:
	var result := RockBottomWallMarkingView.new(); result.name = "WallMarkings"
	result._font = SystemFont.new(); result._font.font_names = PackedStringArray(["Courier New","Liberation Mono","monospace"])
	result._font.font_weight = 700
	if _unit_box == null: _unit_box = BoxMesh.new(); _unit_box.size = Vector3.ONE
	return result

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _has_numbers(row: Dictionary,keys: Array) -> bool:
	for key: String in keys:
		if not _number(row.get(key)): return false
	return true

static func _valid_surfaces(surfaces: Array) -> bool:
	if surfaces.is_empty(): return false
	for entry: Variant in surfaces:
		if not entry is Dictionary or not entry.get("source") is Dictionary or not entry.get("faces") is Dictionary or not _number(entry.get("building_index")): return false
		if not _has_numbers(entry.source,["x","y","w","h"]) or entry.source.w <= 0 or entry.source.h <= 0: return false
		for name: String in ["bottom","leftside","rightside"]:
			if not entry.faces.get(name) is Dictionary: return false
			var face: Dictionary = entry.faces[name]
			if not face.get("transform") is Transform3D or not face.transform.is_finite() or absf(face.transform.basis.determinant()) < 0.00001: return false
			if not face.get("span") is Vector2 or not face.span.is_finite() or face.span.x <= 0 or face.span.y <= 0: return false
			for key: String in ["panels","keepouts"]:
				if not face.get(key) is Array: return false
				for rect: Variant in face[key]:
					if not rect is Rect2 or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x < 0 or rect.size.y < 0: return false
	return true

func _resolve(kind: String,row: Dictionary,surfaces: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for entry: Dictionary in surfaces:
		var source: Dictionary = entry.source
		var face: String = ""
		if kind == "graffiti":
			if absf(float(row.wallX)-float(source.x)-6.0) > 0.001 or absf(float(row.wallW)-float(source.w)+12.0) > 0.001: continue
			if row.y < source.y or row.y > source.y+source.h: continue
			face = row.wallKind
		else:
			if absf(float(row.y)-float(source.y+source.h-30)) < 0.001 and row.x >= source.x+12-0.001 and row.x <= source.x+source.w-36+0.001: face = "bottom"
			elif row.y >= source.y+30-0.001 and row.y <= source.y+source.h-30+0.001:
				if absf(float(row.x)-float(source.x+4)) < 0.001: face = "leftside"
				elif absf(float(row.x)-float(source.x+source.w-20)) < 0.001: face = "rightside"
		if face.is_empty() or not entry.faces.has(face): continue
		candidates.append({"entry":entry,"face":face})
	return candidates[0] if candidates.size() == 1 else {}

static func _contains(outer: Rect2,inner: Rect2) -> bool:
	return inner.position.x >= outer.position.x-0.00001 and inner.position.y >= outer.position.y-0.00001 and inner.end.x <= outer.end.x+0.00001 and inner.end.y <= outer.end.y+0.00001

static func _candidate(values: Array[float],value: float,low: float,high: float) -> void:
	var bounded: float = clampf(value,low,high)
	if not values.has(bounded): values.append(bounded)

static func _place(face: Dictionary,preferred: Vector2,size: Vector2,angle: float) -> Dictionary:
	for factor: float in SCALES:
		var dimensions: Vector2 = size*factor
		var envelope := Vector2(absf(cos(angle))*dimensions.x+absf(sin(angle))*dimensions.y,absf(sin(angle))*dimensions.x+absf(cos(angle))*dimensions.y)
		for raw: Rect2 in face.panels:
			var panel: Rect2 = raw.grow(-0.06)
			if panel.size.x < envelope.x or panel.size.y < envelope.y: continue
			var low: Vector2 = panel.position+envelope*0.5; var high: Vector2 = panel.end-envelope*0.5
			var xs: Array[float] = []; var ys: Array[float] = []
			_candidate(xs,preferred.x,low.x,high.x); _candidate(ys,preferred.y,low.y,high.y)
			_candidate(xs,panel.get_center().x,low.x,high.x); _candidate(ys,panel.get_center().y,low.y,high.y)
			for blocked: Rect2 in face.keepouts:
				_candidate(xs,blocked.position.x-envelope.x*0.5-0.025,low.x,high.x)
				_candidate(xs,blocked.end.x+envelope.x*0.5+0.025,low.x,high.x)
				_candidate(ys,blocked.position.y-envelope.y*0.5-0.025,low.y,high.y)
				_candidate(ys,blocked.end.y+envelope.y*0.5+0.025,low.y,high.y)
			xs.sort_custom(func(a: float,b: float) -> bool: return absf(a-preferred.x) < absf(b-preferred.x))
			ys.sort_custom(func(a: float,b: float) -> bool: return absf(a-preferred.y) < absf(b-preferred.y))
			for y: float in ys:
				for x: float in xs:
					var bounds := Rect2(Vector2(x,y)-envelope*0.5,envelope)
					var clear: bool = _contains(panel,bounds)
					for blocked: Rect2 in face.keepouts:
						if bounds.intersects(blocked.grow(0.01)): clear = false; break
					if clear: return {"center":Vector2(x,y),"scale":factor,"bounds":bounds,"size":dimensions}
	return {}

func _label(parent: Node3D,text: String,at: Vector3,pixel: float,color: Color,align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var label := Label3D.new(); label.name = "Lettering"; label.text = text; label.font = _font
	label.font_size = 48; label.pixel_size = pixel; label.modulate = color
	label.horizontal_alignment = align; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = at; label.outline_size = 0; label.shaded = true
	label.no_depth_test = false; label.double_sided = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label); return label

func _paper(parent: Node3D,at: Vector3,size: Vector3,color: String) -> void:
	var piece := MeshInstance3D.new(); piece.mesh = _unit_box
	piece.material_override = Surface.material("plain",color.trim_prefix("#"),0.96)
	piece.position = at; piece.scale = size; piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)

func _draw_record(kind: String,index: int,row: Variant,surfaces: Array) -> void:
	if not row is Dictionary or not row.get("text") is String or row.text.is_empty() or not _has_numbers(row,["x","y"]):
		_rejected.append({"kind":kind,"index":index,"reason":"invalid_record"}); return
	var text: String = row.text
	var size: Vector2; var angle: float = 0.0; var text_pixel: float
	var palette: Dictionary = {}
	if kind == "graffiti":
		if not _has_numbers(row,["textW","wallX","wallW","rot"]) or not row.get("wallKind") in ["bottom","leftside","rightside"] or not row.get("col") is String or not Color.html_is_valid(row.col):
			_rejected.append({"kind":kind,"index":index,"reason":"invalid_graffiti"}); return
		var sz: float = float(row.get("sz",9)) if _number(row.get("sz")) and row.sz != 0 else 9.0
		if row.textW <= 0 or sz <= 0 or sz > 128: _rejected.append({"kind":kind,"index":index,"reason":"invalid_size"}); return
		var pixels: float = _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x
		if pixels <= 0: _rejected.append({"kind":kind,"index":index,"reason":"empty_glyphs"}); return
		text_pixel = float(row.textW)*0.04/pixels
		# The saved width is an advance, not an ink bound. Bold terminal glyphs
		# overhang it, and Label3D's raster quad includes atlas padding. Reserve
		# an eighth of a rendered line (at least two atlas texels), then the full
		# second-pass offset on each side before rotation/clearance/fit.
		var line_height: float = maxf(sz*0.04,_font.get_height(48)*text_pixel)
		var ink_margin: float = maxf(line_height*0.125,text_pixel*2.0)+0.02
		size = Vector2(float(row.textW)*0.04+ink_margin*2.0,line_height+ink_margin*2.0)
		angle = -float(row.rot)
	else:
		if not _has_numbers(row,["w","h"]) or row.w <= 0 or row.h <= 0 or not row.get("faction") is String:
			_rejected.append({"kind":kind,"index":index,"reason":"invalid_poster"}); return
		var palettes: Dictionary = Content.definition("src/render/structures.js","POSTER_BG",{})
		palette = palettes.get(row.faction,palettes.street)
		text_pixel = 0.16/48.0
		var width: float = float(row.w)*0.04
		var lines: PackedStringArray = text.split("\n")
		for line: String in lines: width = maxf(width,_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x*text_pixel+0.16)
		size = Vector2(width,maxf(float(row.h)*0.04,0.24+float(lines.size())*0.16))
	var resolved: Dictionary = _resolve(kind,row,surfaces)
	if resolved.is_empty(): _rejected.append({"kind":kind,"index":index,"reason":"ambiguous_or_missing_source_wall"}); return
	var source: Dictionary = resolved.entry.source; var face: Dictionary = resolved.entry.faces[resolved.face]
	var u: float
	if kind == "graffiti": u = (float(row.x)+float(row.textW)*0.5-float(row.wallX))/maxf(1.0,float(row.wallW))*float(face.span.x)
	elif resolved.face == "bottom": u = (float(row.x)+float(row.w)*0.5-float(source.x))/float(source.w)*float(face.span.x)
	else:
		u = (float(row.y)-float(source.y))/float(source.h)*float(face.span.x)
		if resolved.face == "rightside": u = float(face.span.x)-u
	var height: float = 1.2 if kind == "graffiti" else 1.55
	if kind == "graffiti": height = 0.7+clampf((float(row.y)-float(source.y))/maxf(1.0,float(source.h)),0.0,1.0)*1.0
	var placement: Dictionary = _place(face,Vector2(u,height),size,angle)
	if placement.is_empty(): _rejected.append({"kind":kind,"index":index,"reason":"no_clear_facade_panel"}); return
	var holder := Node3D.new(); holder.name = kind+"_"+str(index); add_child(holder)
	holder.transform = (face.transform as Transform3D)*Transform3D(Basis(Vector3.BACK,angle),Vector3(placement.center.x,placement.center.y,0))
	# Fitting changes the two-dimensional design; its tiny wall offset is fixed.
	holder.scale = Vector3(float(placement.scale),float(placement.scale),1.0)
	if kind == "graffiti":
		var pigment := Color(row.col); pigment.a = 0.65
		_label(holder,text,Vector3(0,0,0.004),text_pixel,pigment)
		pigment.a = 0.18; _label(holder,text,Vector3(0.02,-0.02,0.006),text_pixel,pigment)
	else:
		_paper(holder,Vector3.ZERO,Vector3(size.x,size.y,0.008),palette.bg)
		for side: float in [-1.0,1.0]: _paper(holder,Vector3(0,side*(size.y*0.5-0.02),0.005),Vector3(size.x,0.04,0.003),"15120e")
		var lines: PackedStringArray = text.split("\n")
		for line: int in range(lines.size()):
			_label(holder,lines[line],Vector3(-size.x*0.5+0.08,size.y*0.5-0.20-float(line)*0.16,0.009),text_pixel,Color(palette.fg),HORIZONTAL_ALIGNMENT_LEFT)
	_records.append({"kind":kind,"index":index,"source":row.duplicate(true),"building_index":resolved.entry.building_index,"face":resolved.face,"bounds":placement.bounds,"scale":placement.scale,"node":holder})

func sync(snapshot: Dictionary,surfaces: Array) -> bool:
	if not snapshot.has("graffiti") or not snapshot.has("posters") or not _valid_surfaces(surfaces): clear(); return false
	var layout := {"graffiti":snapshot.graffiti,"posters":snapshot.posters}
	# Empty-output source retries can advance revision with identical arrays.
	# A revision alone must not rebuild already displayed wall lettering.
	if layout == _last and surfaces == _surfaces: return true
	clear(); _last = layout.duplicate(true); _surfaces = surfaces.duplicate(true)
	for kind: String in ["graffiti","posters"]:
		var rows: Variant = snapshot[kind]
		if rows == null: continue
		if not rows is Array: _rejected.append({"kind":kind,"index":-1,"reason":"layout_not_array"}); continue
		_requested += rows.size()
		for index: int in range(rows.size()): _draw_record("poster" if kind == "posters" else kind,index,rows[index],surfaces)
	_builds += 1
	return true

func clear() -> void:
	for child: Node in get_children(): child.free()
	_last.clear(); _surfaces.clear(); _records.clear(); _rejected.clear(); _requested = 0

func inspect() -> Dictionary:
	var records: Array[Dictionary] = []
	for row: Dictionary in _records:
		var record: Dictionary = row.duplicate(true); record.erase("node"); records.append(record)
	return {"requested":_requested,"placed":_records.size(),"rejected":_rejected.duplicate(true),"records":records,"builds":_builds,"queries":0,"dynamic_shadows":0}
