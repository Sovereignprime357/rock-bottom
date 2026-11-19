extends SceneTree
func _initialize() -> void:
	root.size = Vector2i(640,360)
	root.add_child.call_deferred(load("res://tests/district_grade_raster_probe.gd").new())
