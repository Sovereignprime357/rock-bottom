class_name RockBottomCookingPresentation
extends CanvasLayer
## Read-only heat and smoke view. Input and every gameplay clock belong to Runtime.

const MODES := {"slow":"low and slow","fast":"fast cook","shakes":"shaky special","all":"cook all","propane":"propane"}
const OUTCOMES := {"perfect":"perfect.","ok":"ok.","bad":"bad cook.","burn":"burnt.","undercook":"never set.","soaprock":"soap."}
const CREAM := Color("d4c896")
const GOLD := Color("e8c040")
static var _gradient: GradientTexture2D

class HeatBar extends Control:
	var display: Dictionary = {}
	var texture: Texture2D
	func geometry() -> Dictionary:
		var bar := Rect2(Vector2(12,20),Vector2(maxf(0,size.x-24),28))
		var start := clampf(float(display.get("center",0.5))-float(display.get("half",0.0)),0,1)
		var end := clampf(float(display.get("center",0.5))+float(display.get("half",0.0)),0,1)
		return {"bar":bar,"sweet":Rect2(Vector2(bar.position.x+bar.size.x*start,16),Vector2(bar.size.x*(end-start),36)),
			"burn":Rect2(Vector2(bar.end.x-bar.size.x*float(display.get("burn",0.0)),20),Vector2(bar.size.x*float(display.get("burn",0.0)),28)),
			"center_x":bar.position.x+bar.size.x*float(display.get("center",0.5)),
			"needle_x":bar.position.x+bar.size.x*float(display.get("progress",0.0)),
			"locked_x":bar.position.x+bar.size.x*float(display.get("locked",0.0)),"has_lock":display.get("has_lock",false)}
	func _draw() -> void:
		var g := geometry()
		draw_texture_rect(texture,g.bar,false)
		draw_rect(g.burn,Color(0.54,0.23,0.23,0.40))
		draw_rect(g.sweet,Color(0.83,0.78,0.59,0.18))
		draw_rect(g.sweet,Color("d4c896"),false,1.0)
		draw_rect(Rect2(Vector2(g.center_x-1,10),Vector2(2,6)),Color("d4c896"))
		draw_rect(g.bar,Color("604020"),false,2.0)
		draw_rect(Rect2(Vector2(g.needle_x-1,14),Vector2(2,40)),Color("d4c896"))
		if g.has_lock: draw_rect(Rect2(Vector2(g.locked_x-2,12),Vector2(4,44)),Color("e8c040"))

class Smoke extends Control:
	var opacity: float = 0.0
	var phase: float = 0.0
	func _draw() -> void:
		if opacity <= 0.0: return
		draw_rect(Rect2(Vector2.ZERO,size),Color(180.0/255.0,170.0/255.0,160.0/255.0,opacity*0.85))
		for index: int in range(6):
			var t := phase/0.6+float(index)
			var at := Vector2((sin(t*1.3+index)*0.5+0.5)*size.x,(cos(t*0.9+index)*0.5+0.5)*size.y)
			draw_circle(at,90+index%3*20,Color(60.0/255.0,52.0/255.0,44.0/255.0,opacity*0.6))

var root_control: Control
var smoke: Smoke
var smoke_caption: Label
var dim: ColorRect
var panel: PanelContainer
var title: Label
var subtitle: Label
var bar: HeatBar
var help: Label
var outcome: Label
var resolution: Label
var _visual_phase: float = 0.0
var _layout_pending: bool = false


func _ready() -> void:
	layer = 10
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	smoke = Smoke.new()
	smoke.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(smoke)
	smoke_caption = _label("the smoke is in the floor.",20,Color("1a1810"))
	smoke_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	smoke_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	smoke.add_child(smoke_caption)
	smoke.hide()
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0,0,0,0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(dim)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("1a1810")
	paper.border_color = GOLD
	paper.set_border_width_all(2)
	paper.content_margin_left = 22; paper.content_margin_right = 22
	paper.content_margin_top = 18; paper.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel",paper)
	root_control.add_child(panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation",10)
	panel.add_child(rows)
	title = _label("the heat.",26,GOLD); rows.add_child(title)
	subtitle = _label("",15,CREAM); rows.add_child(subtitle)
	bar = HeatBar.new()
	bar.texture = _heat_texture()
	bar.custom_minimum_size.y = 64
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.resized.connect(bar.queue_redraw)
	rows.add_child(bar)
	help = _label("",14,Color("8c8772")); rows.add_child(help)
	outcome = _label("",24,CREAM); rows.add_child(outcome)
	resolution = _label("",14,CREAM); rows.add_child(resolution)
	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(_queue_layout)
	_layout()
	dim.hide(); panel.hide()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	return label


static func _heat_texture() -> GradientTexture2D:
	if _gradient != null: return _gradient
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0,0.30,0.55,0.82,0.96,1.0])
	ramp.colors = PackedColorArray([Color("353c24"),Color("4a5028"),Color("e8c040"),Color("8a3a3a"),Color("261a12"),Color("1a1810")])
	_gradient = GradientTexture2D.new()
	_gradient.gradient = ramp
	_gradient.width = 256; _gradient.height = 1
	_gradient.fill_from = Vector2.ZERO; _gradient.fill_to = Vector2(1,0)
	return _gradient


static func _number(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float:
		var number := float(value)
		if is_finite(number): return number
	return fallback


static func _count(value: Variant) -> int:
	return int(clampf(floor(_number(value)),0.0,1000000000.0))


func update(snapshot: Dictionary, player: Dictionary, smoke_ms: float, delta: float) -> void:
	if root_control == null: return
	# Decorative motion is independent of the supplied lifetime. Holding smoke_ms
	# constant holds opacity constant, even through repeated or stalled renders.
	if is_finite(delta) and delta > 0: _visual_phase = fmod(_visual_phase+minf(delta,0.10),600.0)
	smoke.opacity = clampf(smoke_ms/2000.0,0,1) if is_finite(smoke_ms) else 0.0
	smoke.phase = _visual_phase
	smoke.visible = smoke.opacity > 0.0
	smoke.queue_redraw()
	var mode: String = snapshot.get("mode","") if snapshot.get("mode") is String else ""
	var phase: String = snapshot.get("phase","") if snapshot.get("phase") is String else ""
	var active: bool = snapshot.get("active") is bool and snapshot.active and MODES.has(mode) and phase in ["fill","idle","hold","resolve"]
	dim.visible = active; panel.visible = active
	if not active: return
	var n := _count(snapshot.get("n"))
	var dirty := mini(n,_count(player.get("dirtySupplies")))
	subtitle.text = "%s — %d packet%s — clean × %d + dirty × %d" % [MODES[mode],n,"" if n == 1 else "s",n-dirty,dirty]
	var locked: Variant = snapshot.get("lockedAt")
	var has_lock: bool = (locked is int or locked is float) and is_finite(float(locked))
	bar.display = {"progress":clampf(_number(snapshot.get("progress")),0,1),"center":clampf(_number(snapshot.get("sweetCenter"),0.5),0,1),
		"half":clampf(_number(snapshot.get("sweetHalf")),0,0.5),"burn":clampf(_number(snapshot.get("burnZone")),0,1),
		"has_lock":has_lock,"locked":clampf(float(locked),0,1) if has_lock else 0.0}
	bar.queue_redraw()
	var result: String = snapshot.get("outcome","") if snapshot.get("outcome") is String else ""
	var label: String = OUTCOMES.get(result,"")
	help.text = "space / tap — lock the heat. esc — walk away." if phase == "fill" else ("you're letting it burn. tap to save it." if phase == "idle" else ("· "+label+" ·" if not label.is_empty() else ""))
	outcome.visible = phase in ["hold","resolve"] and not label.is_empty()
	outcome.text = label.to_upper()
	outcome.add_theme_color_override("font_color",GOLD if result == "perfect" else (Color("8a3a3a") if result == "burn" else (Color("d488d4") if result == "soaprock" else CREAM)))
	resolution.hide(); resolution.text = ""
	if phase == "resolve":
		help.text = "the batch is settling."
		var progress: Variant = snapshot.get("resolution")
		if progress is Dictionary:
			var done := _number(progress.get("processed"),-1)
			var total := _number(progress.get("total"),-1)
			if done >= 0 and done <= total and total > 0 and total <= 1000000000 and floor(done) == done and floor(total) == total:
				resolution.text = "%d / %d packets" % [int(done),int(total)]
				resolution.show()
	_queue_layout()


func _queue_layout() -> void:
	if _layout_pending: return
	_layout_pending = true
	call_deferred("_layout")


func _layout() -> void:
	_layout_pending = false
	if panel == null: return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(580.0,maxf(180.0,viewport_size.x-32.0))
	panel.size.x = width
	panel.size.y = panel.get_combined_minimum_size().y
	# Preserve all text and the result in unusually short/tiny host viewports.
	# Ordinary desktop/portrait sizes keep the authored font size and bar height.
	var available := Vector2(maxf(1,viewport_size.x-32),maxf(1,viewport_size.y-32))
	var fit := minf(1.0,minf(available.x/maxf(1,panel.size.x),available.y/maxf(1,panel.size.y)))
	panel.scale = Vector2.ONE*fit
	panel.position = (viewport_size-panel.size*fit)*0.5
	if smoke != null: smoke.queue_redraw()
