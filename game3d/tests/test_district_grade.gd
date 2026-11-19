extends SceneTree
## Draft gate only. Native/Web shader raster and timing acceptance are separate.
const Grade = preload("res://scripts/district_grade.gd")
const View = preload("res://scripts/district_grade_view.gd")
var checks: int = 0
var failures: Array[String] = []
var completed_lookups: int = 0
var completed_blends: int = 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _point(value: Variant) -> float:
	if value is String:
		if value == "NaN": return NAN
		if value == "Infinity": return INF
		if value == "-Infinity": return -INF
	return float(value)

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func _recipe(value: Dictionary) -> Dictionary:
	return {"multiply":_vector(value.multiply),"multiplyAlpha":float(value.multiplyAlpha),"overlay":_vector(value.overlay),"overlayAlpha":float(value.overlayAlpha)}

func _same_recipe(actual: Dictionary,expected: Dictionary) -> bool:
	return not actual.is_empty() and actual.multiply.distance_to(_vector(expected.multiply)) < 0.0000002 and actual.overlay.distance_to(_vector(expected.overlay)) < 0.0000002 and actual.multiplyAlpha == expected.multiplyAlpha and actual.overlayAlpha == expected.overlayAlpha

func _run() -> void:
	var fixture_path: String = "res://tests/fixtures/district_grade_reference.json"
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	_check(raw is Dictionary,"draft source fixture exists")
	if raw is Dictionary:
		var fixture: Dictionary = raw
		_check(fixture.format == "rock-bottom-district-grade-draft-reference" and fixture.counts.lookups == 676 and fixture.counts.grades == 39 and fixture.counts.blends == 585 and fixture.counts.rngDraws == 0,"complete unchanged-source/standard-math census")
		var models: Dictionary = {}
		for id: String in fixture.variants:
			models[id] = Grade.new(fixture.variants[id])
			_check(models[id].ready(),"validated source variant: "+id)
		for row: Dictionary in fixture.lookups:
			var actual: Dictionary = models[row.variant].at(_point(row.point[0]),_point(row.point[1]))
			_check(_same_recipe(actual,row.expected),"unchanged source closed-edge/first-match lookup: "+row.id)
			completed_lookups += 1
		for row: Dictionary in fixture.blends:
			var actual: Vector3 = Grade.blend_rgb(_vector(row.background),_recipe(row.recipe))
			# Only float32 Vector3 storage differs from the double standards fixture.
			_check(actual.distance_to(_vector(row.expected)) < 0.0000002,"captured multiply-then-overlay equation: "+row.id)
			completed_blends += 1
		_test_detached_and_invalid(fixture.variants.source)
		_test_blend_properties()
		_test_view(fixture.variants.source)
	_check(completed_lookups == 676 and completed_blends == 585,"all lookup and blend cases actually completed")
	if failures.is_empty():
		print("DISTRICT GRADE DRAFT GATE: PASS (%d checks;676 source lookups/585 mathematical blends; GPU/native/Web acceptance pending)"%checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("DISTRICT GRADE DRAFT GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks])
		quit(1)

func _test_detached_and_invalid(source: Dictionary) -> void:
	var data: Dictionary = source.duplicate(true)
	var model := Grade.new(data)
	var before: Dictionary = model.at(1000,800)
	_check(model.inspect() == {"ready":true,"zones":23,"regions":15,"grades":39,"recipes":6},"source catalog compiles six bounded recipes")
	data.zones[0].x = -10000; data.ambientGrades.block.multiply = "255,255,255"
	_check(model.at(1000,800) == before,"caller data mutation cannot change compiled geography/palette")
	var detached: Dictionary = model.at(1000,800); detached.multiply = Vector3.ZERO
	var bank: Array[Dictionary] = model.recipes(); bank[0].overlayAlpha = 1.0
	_check(model.at(1000,800) == before and model.recipes()[0].overlayAlpha != 1.0,"returned recipes are detached from owner")
	for field: String in ["zones","terrainRegions","ambientGrades"]:
		var invalid: Dictionary = source.duplicate(true); invalid[field] = null
		var rejected := Grade.new(invalid)
		_check(not rejected.ready() and rejected.at(0,0).is_empty(),"malformed catalog fails atomically: "+field)
	var excessive: Dictionary = source.duplicate(true)
	while excessive.zones.size() <= Grade.MAX_RECORDS: excessive.zones.append(excessive.zones[0].duplicate(true))
	_check(not Grade.new(excessive).ready(),"bounded catalog rejects excess instead of dropping late source rectangles")
	var invalid_color: Dictionary = source.duplicate(true); invalid_color.ambientGrades.default.multiply = "256,0,0"
	_check(not Grade.new(invalid_color).ready(),"invalid RGB cannot enter a shader material")
	var invalid_alpha: Dictionary = source.duplicate(true); invalid_alpha.ambientGrades.default.overlayAlpha = NAN
	_check(not Grade.new(invalid_alpha).ready(),"nonfinite alpha cannot enter a shader material")

func _test_blend_properties() -> void:
	var identity := {"multiply":Vector3.ZERO,"multiplyAlpha":0.0,"overlay":Vector3.ONE,"overlayAlpha":0.0}
	var color := Vector3(0.11,0.51,0.93)
	_check(Grade.blend_rgb(color,identity) == color,"zero alpha identity retains encoded values")
	var boundary := {"multiply":Vector3.ONE,"multiplyAlpha":0.0,"overlay":Vector3(0.2,0.8,0.5),"overlayAlpha":1.0}
	_check(Grade.blend_rgb(Vector3.ONE*0.5,boundary).distance_to(boundary.overlay) < 0.0000001,"overlay branches agree at backdrop .5")
	_check(not Grade.blend_rgb(Vector3(NAN,0,0),identity).is_finite(),"invalid CPU color is rejected")
	_check(not Grade.blend_rgb(Vector3(-0.1,0,0),identity).is_finite(),"opaque SDR equation does not silently normalize out-of-range input")

func _test_view(source: Dictionary) -> void:
	var model := Grade.new(source)
	var view := View.new(model); root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_check(view.inspect().materials == 6 and not view.visible and view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.focus_mode == Control.FOCUS_NONE,"one passive rect starts hidden with fixed six-material bank")
	_check(not view.is_processing() and not view.is_physics_processing(),"grade view owns no frame/physics clock")
	_check(view.sync(1000,800,"playing") and view.visible,"playing selects source grade")
	var first: Material = view.material
	var changes: int = view.inspect().material_changes
	for tick: int in range(120): view.sync(1000+float(tick)*0.01,800,"playing")
	_check(view.material == first and view.inspect().material_changes == changes and view.inspect().materials == 6,"stable district performs no new material assignment/allocation")
	for mode: String in ["paused","dialogue","ending","cookmini"]:
		_check(view.sync(1000,800,mode) and view.visible,"world grade remains beneath modal state: "+mode)
	_check(view.sync(1000,800,"title") and not view.visible,"title disables screen pass")
	_check(view.sync(1000,800,"playing") and view.material == first,"title resume reuses existing grade material")
	view.sync(1700,1400,"playing")
	_check(view.material != first and view.inspect().material_changes == changes+1,"different district selects its immutable recipe")
	view.sync(1000,800,"playing")
	_check(view.material == first,"returning district reuses original material resource")
	var second := View.new(model); root.add_child(second); second.sync(1000,800,"playing")
	_check(second.material != view.material and (second.material as ShaderMaterial).shader == (view.material as ShaderMaterial).shader,"instances share immutable shader but own independent fixed material banks")
	var snapshot: Dictionary = model.at(1000,800)
	view.clear(); _check(not view.visible and view.inspect().selected == -1 and model.at(1000,800) == snapshot,"presentation reset cannot alter source grade facts")
	view.sync(1000,800,"playing")
	var old_transparency: bool = root.transparent_bg; root.transparent_bg = true
	_check(not view.sync(1000,800,"playing") and not view.visible,"transparent viewport refuses opaque equation")
	root.transparent_bg = old_transparency
	view.free(); second.free()
