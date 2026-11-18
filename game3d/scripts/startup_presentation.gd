class_name RockBottomStartupPresentation
extends CanvasLayer
## Opaque startup view only. The scene owns preparation, readiness and gameplay.

var cover: ColorRect
var stage_label: Label
var count_label: Label
var progress: ProgressBar
var _stage: String = ""
var _completed: int = 0
var _total: int = 0
var _started_usec: int = 0
var _timings: Array[Dictionary] = []
var _finished: bool = false


func _ready() -> void:
	layer = 100
	cover = ColorRect.new()
	cover.name = "OpaqueStartup"
	cover.color = Color("1a1810")
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(360,0)
	rows.add_theme_constant_override("separation",14)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(rows)
	var title := Label.new()
	title.text = "ROCK BOTTOM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",36)
	title.add_theme_color_override("font_color",Color("e8c040"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(title)
	stage_label = Label.new()
	stage_label.text = "the block is getting dressed."
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size",20)
	stage_label.add_theme_color_override("font_color",Color("d4c896"))
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(stage_label)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0,10)
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var empty := StyleBoxFlat.new()
	empty.bg_color = Color("343326")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a49a57")
	progress.add_theme_stylebox_override("background",empty)
	progress.add_theme_stylebox_override("fill",fill)
	rows.add_child(progress)
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size",16)
	count_label.add_theme_color_override("font_color",Color("a79e75"))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(count_label)
	progress.hide()


func show_stage(text: String, completed: int, total: int) -> void:
	if cover == null or _finished: return
	if text != _stage or _started_usec == 0:
		_close_stage()
		_stage = text
		_started_usec = Time.get_ticks_usec()
	_completed = clampi(completed,0,maxi(0,total))
	_total = maxi(0,total)
	stage_label.text = text
	progress.visible = _total > 0
	progress.max_value = maxi(1,_total)
	progress.value = _completed
	count_label.text = "%d / %d" % [_completed,_total] if _total > 0 else ""


func stage_timings() -> Array[Dictionary]:
	var result: Array[Dictionary] = _timings.duplicate(true)
	if _started_usec > 0:
		result.append({"stage":_stage,"completed":_completed,"total":_total,"elapsed_usec":Time.get_ticks_usec()-_started_usec})
	return result


func _close_stage() -> void:
	if _started_usec == 0: return
	_timings.append({"stage":_stage,"completed":_completed,"total":_total,"elapsed_usec":Time.get_ticks_usec()-_started_usec})
	_started_usec = 0


func finish() -> void:
	if _finished: return
	_close_stage()
	_finished = true
	if cover != null: cover.hide()
