extends ColorRect
## One passive SDR screen pass. Root owns placement beneath all feedback/UI.
const GRADE_SHADER = preload("district_grade.gdshader")
var _model: RefCounted
var _materials: Array[ShaderMaterial] = []
var _selected: int = -1
var _material_changes: int = 0
var _world_feedback_offset := Vector2.ZERO
var _feedback_uniform_changes: int = 0

func _init(model: RefCounted = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	set_process(false); set_physics_process(false)
	_model = model
	if model == null or not model.ready(): return
	for recipe: Dictionary in model.recipes():
		var surface := ShaderMaterial.new()
		surface.shader = GRADE_SHADER
		surface.set_shader_parameter("multiply_rgb",recipe.multiply)
		surface.set_shader_parameter("multiply_alpha",recipe.multiplyAlpha)
		surface.set_shader_parameter("overlay_rgb",recipe.overlay)
		surface.set_shader_parameter("overlay_alpha",recipe.overlayAlpha)
		_materials.append(surface)

func sync(source_x: float,source_y: float,mode: String) -> bool:
	if _model == null or not _model.ready() or _materials.is_empty(): clear(); return false
	if is_inside_tree() and (get_viewport().use_hdr_2d or get_viewport().transparent_bg): clear(); return false
	if mode == "title":
		visible = false
		return true
	var profile: Dictionary = _model.at(source_x,source_y)
	var index: int = int(profile.index)
	if index != _selected:
		material = _materials[index]; _selected = index; _material_changes += 1
		_materials[index].set_shader_parameter("world_feedback_offset_px",_world_feedback_offset)
		_feedback_uniform_changes += 1
	if not visible: visible = true
	return true

func clear() -> void:
	set_world_feedback_offset(Vector2.ZERO)
	visible = false; _selected = -1

func inspect() -> Dictionary:
	return {"visible":visible,"selected":_selected,"materials":_materials.size(),"material_changes":_material_changes,"screen_reads_per_fragment":1,"world_feedback_offset":_world_feedback_offset,"feedback_uniform_changes":_feedback_uniform_changes}

func set_world_feedback_offset(offset: Vector2) -> bool:
	if not offset.is_finite() or absf(offset.x) > 64.0 or absf(offset.y) > 64.0: return false
	if offset == _world_feedback_offset: return true
	_world_feedback_offset = offset
	if _selected >= 0:
		_materials[_selected].set_shader_parameter("world_feedback_offset_px",offset)
		_feedback_uniform_changes += 1
	return true
