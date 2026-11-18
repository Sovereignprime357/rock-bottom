extends CanvasLayer

const CREAM := Color("d4c896")
const GOLD := Color("e8c040")
var root: Control
var status: Label
var pocket: Label
var objective: Label
var prompt: Label
var receipt: Label
var look_hint: Label
var health: ProgressBar
var shakes: ProgressBar
var crosshair: Label
var modal: PanelContainer
var menu_box: VBoxContainer
var tint: ColorRect
var receipt_time := 0.0

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_shadow_color", "Label", Color(0.03, 0.03, 0.02, 0.85))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("746e57"))
	theme.set_stylebox("normal", "Button", _style(Color("29291f"), Color("5c5942"), 1))
	theme.set_stylebox("hover", "Button", _style(Color("3b3925"), GOLD, 1))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD, 1))
	theme.set_stylebox("pressed", "Button", _style(Color("4a5028"), GOLD, 1))
	theme.set_stylebox("disabled", "Button", _style(Color("1e201b"), Color("3a3a2f"), 1))
	root.theme = theme
	tint = ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0, 0, 0, 0)
	root.add_child(tint)
	_plate(Control.PRESET_TOP_LEFT, Vector2(20, 16), Vector2(510, 70))
	_plate(Control.PRESET_TOP_RIGHT, Vector2(-358, 16), Vector2(338, 70))
	var meter_back := ColorRect.new()
	meter_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	meter_back.position = Vector2(20, -124)
	meter_back.size = Vector2(250, 108)
	meter_back.color = Color(0.06, 0.07, 0.05, 0.78)
	meter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(meter_back)
	status = _label("THE BLOCK  /  DAY 1", 18, GOLD)
	status.position = Vector2(32, 25)
	root.add_child(status)
	objective = _label("BAD IDEA   find ten dollars.", 18)
	objective.position = Vector2(32, 55)
	root.add_child(objective)
	pocket = _label("", 19)
	pocket.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pocket.position = Vector2(-338, 26)
	pocket.size = Vector2(306, 65)
	pocket.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(pocket)
	var meters := VBoxContainer.new()
	meters.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	meters.position = Vector2(32, -112)
	meters.size = Vector2(226, 82)
	root.add_child(meters)
	meters.add_child(_label("body", 14))
	health = _bar(Color("aaa269"))
	meters.add_child(health)
	meters.add_child(_label("shakes", 14))
	shakes = _bar(Color("d488d4"))
	meters.add_child(shakes)
	crosshair = _label("·", 32, CREAM)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -22)
	root.add_child(crosshair)
	prompt = _label("", 20)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-300, -109)
	prompt.size = Vector2(600, 75)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	receipt = _label("", 19)
	receipt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	receipt.position = Vector2(-420, -190)
	receipt.size = Vector2(388, 150)
	receipt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	receipt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(receipt)
	look_hint = _label("[hold right mouse] look", 14)
	look_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	look_hint.position = Vector2(-290, -31)
	look_hint.size = Vector2(268, 22)
	look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	look_hint.hide()
	root.add_child(look_hint)
	modal = PanelContainer.new()
	modal.custom_minimum_size.x = 580
	modal.add_theme_stylebox_override("panel", _style(Color(0.072, 0.077, 0.060, 0.97), Color("777044"), 1))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(modal)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 27)
	modal.add_child(margin)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	margin.add_child(menu_box)
	modal.hide()

func _plate(anchor: int, at: Vector2, size: Vector2) -> void:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(anchor)
	panel.position = at
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := _style(Color(0.06, 0.065, 0.045, 0.72), Color(0.38, 0.35, 0.22, 0.65), 1)
	paper.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", paper)
	root.add_child(panel)

func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text: String, font_size: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 8)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("27291f"), Color("4c4d3a"), 1))
	bar.add_theme_stylebox_override("fill", _style(color, color, 0))
	return bar

func update_stats(sim: RefCounted, zone: String) -> void:
	status.text = "%s  /  DAY %d" % [zone, sim.day]
	pocket.text = "$%d     rocks %d     copper %d\nbrain %d     cred %d" % [sim.cash, sim.rocks, sim.copper, sim.brain, sim.cred]
	health.value = sim.hp
	shakes.value = sim.shakes
	if sim.high_remaining > 0:
		objective.text = "ROCKED UP   %.1fs" % sim.high_remaining
		objective.modulate = GOLD
		tint.color = Color(0.80, 0.61, 0.12, 0.035)
	elif sim.crash_remaining > 0:
		objective.text = "THE CRASH   %.1fs" % sim.crash_remaining
		objective.modulate = Color("d488d4")
		tint.color = Color(0.35, 0.17, 0.36, 0.09)
	else:
		objective.modulate = CREAM
		tint.color = Color(0, 0, 0, 0)
		if sim.rocks > 0: objective.text = "BAD IDEA   smoke a rock at the block."
		elif sim.cash >= 10: objective.text = "BAD IDEA   buy a rock from tre bag tony."
		else: objective.text = "BAD IDEA   find ten dollars."

func show_receipt(text: String,duration_ms: float = 4000.0) -> void:
	receipt.text = text
	receipt_time = clampf(duration_ms/1000.0,0.05,60.0) if is_finite(duration_ms) else 4.0

func _process(delta: float) -> void:
	if receipt_time > 0:
		receipt_time -= delta
		receipt.modulate.a = minf(receipt_time, 1.0)

func menu(title: String, body: String, options: Array, big: bool = false) -> void:
	look_hint.hide()
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()
	var heading := _label(title, 55 if big else 27, GOLD)
	menu_box.add_child(heading)
	var copy := _label(body, 18)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(490, 62)
	menu_box.add_child(copy)
	var separator := HSeparator.new()
	menu_box.add_child(separator)
	for option: Dictionary in options:
		var button := Button.new()
		button.text = str(option.label)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 42
		button.disabled = bool(option.get("disabled", false))
		button.pressed.connect(option.action)
		menu_box.add_child(button)
	modal.show()
	crosshair.hide()
	prompt.hide()
	# CenterContainer owns placement after every content/layout change.
	modal.reset_size()

func close_menu() -> void:
	modal.hide()
	crosshair.show()
	prompt.show()
