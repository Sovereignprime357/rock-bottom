extends SceneTree

const Surfaces = preload("res://scripts/surface_kit.gd")
const Batcher = preload("res://scripts/mesh_batcher.gd")
const Characters = preload("res://scripts/character_art.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_surfaces()
	_test_periodic_fields()
	_test_geometry()
	_test_cells_and_guards()
	_test_palette_batching()
	_test_character_geometry()
	if failures.is_empty():
		print("3D ART GATE: PASS (%d checks; deterministic periodic tiles, transformed geometry, bounded character meshes, selective normals, render state and untouched pivots/collision)" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("3D ART GATE: FAIL (%d failures / %d checks)" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_surfaces() -> void:
	var kinds: Array[String] = ["brick", "plaster", "concrete", "asphalt", "wood", "painted_metal", "fabric", "skin", "rubber"]
	for kind: String in kinds:
		var paint: StandardMaterial3D = Surfaces.material(kind, "604020")
		_check(paint == Surfaces.material(kind, "#604020"), "%s cache normalizes color spelling" % kind)
		_check(paint != Surfaces.material(kind, "8a3a3a"), "%s keeps distinct palette materials" % kind)
		_check(paint.albedo_texture == Surfaces.material(kind, "8a3a3a").albedo_texture, "%s shares one tile across palette colors" % kind)
		_check(paint.albedo_color.is_equal_approx(Color("604020")), "%s preserves authored base color" % kind)
		_check(paint.albedo_texture != null and paint.albedo_texture.get_width() == 128 and paint.albedo_texture.get_height() == 128, "%s uses a small actual material texture" % kind)
		var first: Image = Surfaces._tile(kind)
		var uploaded: Image = paint.albedo_texture.get_image()
		_check(uploaded != null and uploaded.get_data() == first.get_data(), "%s material uses the generated pixels and mip chain" % kind)
		# Interleave another texture and perturb the global RNG; a global random
		# stream must not change an existing material's generated pixels.
		seed(971)
		var discarded: Image = Surfaces._tile("asphalt" if kind != "asphalt" else "brick")
		var second: Image = Surfaces._tile(kind)
		_check(first.get_data() == second.get_data() and discarded != null, "%s tile generation is repeatable after other work" % kind)
		_check(first.has_mipmaps() and first.get_mipmap_count() == 7, "%s has the complete 128px mip chain" % kind)
		var statistics: Vector3 = _tile_statistics(first)
		_check(statistics.z > 0.86 and statistics.x >= 0.60 and statistics.y <= 1.0, "%s keeps the palette readable (mean %.3f)" % [kind, statistics.z])
		_check(statistics.y - statistics.x > 0.07, "%s has visible but restrained surface detail" % kind)
		_check(paint.uv1_triplanar and paint.texture_repeat, "%s tiles without needing authored UVs" % kind)
		_check(paint.uv1_world_triplanar == (kind not in ["fabric", "skin", "rubber"]), "%s uses the correct world/actor coordinate space" % kind)
		_check(paint.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s enables mip sampling" % kind)
	var brick: Image = Surfaces._tile("brick")
	_check(brick.get_pixel(8, 8).r > brick.get_pixel(8, 0).r + 0.12, "brick faces read clearly above mortar joints")
	_check(brick.get_data() != Surfaces._tile("asphalt").get_data(), "masonry and road are different surfaces")
	var plain: StandardMaterial3D = Surfaces.material("plain", "d4c896")
	_check(plain.albedo_texture == null and not plain.emission_enabled, "plain material stays untextured and unlit")
	_check(plain == Surfaces.material("unknown", "d4c896"), "unknown surface falls back to plain")
	_check(plain != Surfaces.material("plain", "d4c896", 0.5), "roughness is part of the material cache key")
	var lamp: StandardMaterial3D = Surfaces.material("plain", "e8c040", 0.94, 1.5)
	_check(lamp.emission_enabled and is_equal_approx(lamp.emission_energy_multiplier, 1.5), "fixture emission remains explicit")
	_check(Surfaces.material("skin", "ad8055").uv1_scale.x > 0.0, "character texture scale is finite and positive")


func _tile_statistics(tile: Image) -> Vector3:
	var minimum: float = 1.0
	var maximum: float = 0.0
	var total: float = 0.0
	for y: int in range(tile.get_height()):
		for x: int in range(tile.get_width()):
			var value: float = tile.get_pixel(x, y).r
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			total += value
	return Vector3(minimum, maximum, total / float(tile.get_width() * tile.get_height()))


func _test_periodic_fields() -> void:
	# Test the properties that make broad dirt fields safe to tile. Include
	# negative coordinates and subpixel samples; integer-only tests miss seams.
	for cell: int in [8, 16, 32]:
		var bounded: bool = true
		var periodic: bool = true
		var continuous: bool = true
		for salt: int in [11, 19, 37, 47]:
			for at: Vector2 in [Vector2(-128.25, -0.125), Vector2(-1, 129.5), Vector2.ZERO, Vector2(7.625, 15.75), Vector2(63.2, 127.9)]:
				var value: float = Surfaces._field(at.x, at.y, cell, salt)
				bounded = bounded and is_finite(value) and value >= 0.0 and value <= 1.0
				periodic = periodic and is_equal_approx(value, Surfaces._field(at.x + 128.0, at.y, cell, salt))
				periodic = periodic and is_equal_approx(value, Surfaces._field(at.x, at.y - 128.0, cell, salt))
			for seam: float in [0.0, float(cell), 128.0]:
				continuous = continuous and absf(Surfaces._field(seam - 0.001, 3.75, cell, salt) - Surfaces._field(seam + 0.001, 3.75, cell, salt)) < 0.00001
				continuous = continuous and absf(Surfaces._field(11.5, seam - 0.001, cell, salt) - Surfaces._field(11.5, seam + 0.001, cell, salt)) < 0.00001
		_check(bounded, "%dpx wear field stays finite and within neutral modulation bounds" % cell)
		_check(periodic, "%dpx wear field repeats exactly across both 128px tile axes" % cell)
		_check(continuous, "%dpx wear field has no jumps at lattice or tile boundaries" % cell)


func _test_character_geometry() -> void:
	for id: String in ["tony", "pete", "yuri", "lurch", "possum", "brutus", "player_hands"]:
		var actor: Node3D = Characters.create_character(id)
		root.add_child(actor)
		var points: Array[Vector3] = _points(actor)
		var finite_points: bool = not points.is_empty()
		for point: Vector3 in points:
			finite_points = finite_points and point.is_finite()
		_check(finite_points, "%s contains finite authored geometry" % id)
		if finite_points:
			var bounds: AABB = _bounds(points)
			# Broad physical envelopes catch spikes or a unit/scale mistake without
			# freezing a face, proportion, triangle count or exact silhouette.
			var max_size := Vector3(1.8, 2.5, 1.5)
			var min_height: float = 1.4
			if id in ["possum", "brutus"]:
				max_size = Vector3(1.2, 1.4, 2.5)
				min_height = 0.25
			elif id == "player_hands":
				max_size = Vector3(1.4, 1.4, 1.4)
				min_height = 0.15
			_check(bounds.size.x > 0.15 and bounds.size.x <= max_size.x and bounds.size.y >= min_height and bounds.size.y <= max_size.y and bounds.size.z > 0.15 and bounds.size.z <= max_size.z, "%s stays within a human/creature/viewmodel physical envelope (%s)" % [id, bounds.size])
			if id != "player_hands":
				_check(bounds.position.y >= -0.15 and bounds.position.y < 0.15, "%s remains grounded at its unchanged art origin" % id)
		var normals: Dictionary = {"valid": true, "triangles": 0, "flat": 0, "smooth": 0}
		_character_normal_stats(actor, normals)
		_check(normals.valid and normals.triangles > 0, "%s visible triangles have finite unit normals facing their drawn side" % id)
		if id in ["tony", "pete", "yuri", "lurch"]:
			var head: Node3D = actor.get_node_or_null("head")
			var head_normals: Dictionary = {"valid": true, "triangles": 0, "flat": 0, "smooth": 0}
			if head != null: _character_normal_stats(head, head_normals)
			_check(head_normals.smooth > 0 and head_normals.flat > 0, "%s head combines softened broad forms with hard detail planes" % id)
		actor.free()


func _character_normal_stats(node: Node3D, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_NORMAL] == null or arrays[Mesh.ARRAY_NORMAL].size() != vertices.size():
				stats.valid = false
				continue
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			if count % 3 != 0:
				stats.valid = false
				continue
			for offset: int in range(0, count, 3):
				var a: int = indices[offset] if not indices.is_empty() else offset
				var b: int = indices[offset + 1] if not indices.is_empty() else offset + 1
				var c: int = indices[offset + 2] if not indices.is_empty() else offset + 2
				var cross: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
				# Legacy pole triangles have zero area and draw no pixels. They do
				# not license bad normals on the actual visible surface beside them.
				if cross.length_squared() < 1e-16: continue
				var face_normal: Vector3 = -cross.normalized()
				var flat: bool = true
				for index: int in [a, b, c]:
					var normal: Vector3 = normals[index]
					stats.valid = stats.valid and normal.is_finite() and absf(normal.length() - 1.0) < 0.001 and normal.dot(face_normal) > 0.0
					flat = flat and normal.distance_to(face_normal) < 0.001
				stats.triangles += 1
				if flat: stats.flat += 1
				else: stats.smooth += 1
	for child: Node in node.get_children():
		if child is Node3D: _character_normal_stats(child as Node3D, stats)


func _box(parent: Node3D, paint: Material, position_at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 0.8, 1.7)
	part.mesh = mesh
	part.material_override = paint
	part.position = position_at
	parent.add_child(part)
	return part


func _triangle(parent: Node3D, paint: Material, transform_at: Transform3D) -> MeshInstance3D:
	# This sloped face catches the tempting but wrong basis*normal transform:
	# its normal is not aligned with an axis under nonuniform scale and shear.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3(0, 1, 1)])
	var normal: Vector3 = Vector3(0, 1, -1).normalized()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.1, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.9)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color("e8c040"), Color("4a5028"), Color("d4c896")])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, paint)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.transform = transform_at
	parent.add_child(part)
	return part


func _test_geometry() -> void:
	var fixture := Node3D.new()
	fixture.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.37, -0.05)), Vector3(8, 2, -4))
	root.add_child(fixture)
	var paint: StandardMaterial3D = Surfaces.material("concrete", "d4c896")
	var other: StandardMaterial3D = Surfaces.material("brick", "8a3a3a")
	var first: MeshInstance3D = _box(fixture, paint, Vector3(2, 1, 2))
	first.rotation = Vector3(0.3, 0.6, 0.2)
	first.scale = Vector3(1.8, 0.7, 1.2)
	_box(fixture, paint, Vector3(4, 2, 3))
	var mirrored: MeshInstance3D = _box(fixture, paint, Vector3(6, 2, 5))
	mirrored.scale = Vector3(-1.1, 1.4, 0.9)
	var shadowless: MeshInstance3D = _box(fixture, paint, Vector3(2, 1, 6))
	shadowless.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadowless.layers = 3
	var alternate: MeshInstance3D = _box(fixture, other, Vector3(4, 1, 6))
	alternate.material_overlay = Surfaces.material("plain", "604020")
	var basis: Basis = Basis.from_euler(Vector3(0.2, -0.4, 0.3)).scaled(Vector3(2.0, 0.6, 1.4))
	basis.y += basis.x * 0.15
	_triangle(fixture, paint, Transform3D(basis, Vector3(1, 2, 4)))
	_triangle(fixture, paint, Transform3D(basis.scaled(Vector3(-1, 1, 1)), Vector3(5, 2, 4)))
	var pivot := Node3D.new()
	pivot.name = "animated_head"
	fixture.add_child(pivot)
	var nested: MeshInstance3D = _box(pivot, other, Vector3(0, 3, 0))
	var retained: MeshInstance3D = _box(fixture, other, Vector3(-2, 1, 2))
	var child_label := Label3D.new()
	child_label.text = "occupied"
	retained.add_child(child_label)
	var target: MeshInstance3D = _box(fixture, other, Vector3(-3, 1, 4))
	target.set_meta("interaction_id", "pete")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	fixture.add_child(body)
	var lamp := OmniLight3D.new()
	fixture.add_child(lamp)
	var label := Label3D.new()
	label.text = "pete"
	fixture.add_child(label)
	var before: Array[Vector3] = _points(fixture)
	var before_attributes: Dictionary = _attributes(fixture)
	var before_bounds: AABB = _bounds(before)
	var metrics: Dictionary = Batcher.batch_children(fixture, 0.0)
	var after: Array[Vector3] = _points(fixture)
	_check(metrics.source_meshes == 7, "only seven eligible direct static leaves are consumed")
	_check(metrics.batches == 4 and metrics.surfaces == 4, "compatible leaves merge while material, shadow state and vertex format remain separate")
	_check(metrics.triangles == 62, "five box primitives and two custom faces retain all 62 triangles")
	_check(_same_points(before, after), "every world-space triangle vertex survives rotation, shear, mirror and nonuniform scale")
	_check(before_bounds.is_equal_approx(_bounds(after)), "the world-space geometry bounds are preserved")
	_check(before_attributes == _attributes(fixture), "vertex UVs and colors remain attached to the same positions")
	_check(is_instance_valid(pivot) and nested.get_parent() == pivot, "nested moving pivots and their meshes retain identity")
	_check(is_instance_valid(retained) and child_label.get_parent() == retained, "a mesh with descendants is left untouched")
	_check(is_instance_valid(target) and target.get_meta("interaction_id") == "pete", "target metadata retains its original mesh handle")
	_check(body.get_parent() == fixture and shape.get_parent() == body and shape.shape is BoxShape3D, "physics body and collision shape stay untouched")
	_check(lamp.get_parent() == fixture and label.get_parent() == fixture and label.text == "pete", "light and label siblings remain untouched")
	var found_shadowless: bool = false
	var found_overlay: bool = false
	var valid_normals: bool = true
	for child: Node in fixture.get_children():
		if child is MeshInstance3D and child.has_meta("slice_static_batch"):
			var batch: MeshInstance3D = child as MeshInstance3D
			valid_normals = valid_normals and _normals_valid(batch)
			if batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				var batched_paint: StandardMaterial3D = batch.get_active_material(0) as StandardMaterial3D
				found_shadowless = batch.layers == 3 and batched_paint.albedo_texture == paint.albedo_texture and batched_paint.vertex_color_use_as_albedo
			if batch.get_active_material(0) == other:
				found_overlay = batch.material_overlay == Surfaces.material("plain", "604020")
	_check(valid_normals, "baked normals stay unit, perpendicular and correctly wound, including mirrored faces")
	_check(found_shadowless, "shadow toggle, layer mask and material survive batching")
	_check(found_overlay, "material overlay is preserved independently of base material")
	var repeat: Dictionary = Batcher.batch_children(fixture, 0.0)
	_check(repeat.source_meshes == 0 and _same_points(after, _points(fixture)), "a second batching pass leaves existing batches and protected objects unchanged")
	fixture.free()


func _points(node: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = node as MeshInstance3D
		# Mesh.get_faces() builds a TriangleMesh that snaps to 0.0001m. Inspect
		# actual render arrays instead, so the oracle does not invent geometry drift.
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex: Vector3 in vertices:
					points.append(instance.global_transform * vertex)
			else:
				for index: int in indices:
					points.append(instance.global_transform * vertices[index])
	for child: Node in node.get_children():
		if child is Node3D:
			points.append_array(_points(child as Node3D))
	return points


func _same_points(first: Array[Vector3], second: Array[Vector3]) -> bool:
	if first.size() != second.size(): return false
	var remaining: Array[Vector3] = second.duplicate()
	for vertex: Vector3 in first:
		var found: int = -1
		for index: int in range(remaining.size()):
			if vertex.distance_to(remaining[index]) < 0.00005:
				found = index
				break
		if found < 0: return false
		remaining.remove_at(found)
	return true


func _bounds(points: Array[Vector3]) -> AABB:
	if points.is_empty(): return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(point)
	return result


func _attributes(node: Node3D) -> Dictionary:
	var result: Dictionary = {}
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty() or arrays[Mesh.ARRAY_TEX_UV] == null or arrays[Mesh.ARRAY_TEX_UV].is_empty(): continue
			for index: int in range(vertices.size()):
				var position_at: Vector3 = instance.global_transform * vertices[index]
				var key: String = "%.3f,%.3f,%.3f/%s/%s" % [position_at.x, position_at.y, position_at.z, str(arrays[Mesh.ARRAY_TEX_UV][index]), str(arrays[Mesh.ARRAY_COLOR][index])]
				result[key] = int(result.get(key, 0)) + 1
	for child: Node in node.get_children():
		if child is Node3D:
			var nested: Dictionary = _attributes(child as Node3D)
			for key: String in nested:
				result[key] = int(result.get(key, 0)) + int(nested[key])
	return result


func _normals_valid(instance: MeshInstance3D) -> bool:
	# Godot packs normals/tangents into 16-bit octahedral coordinates even when
	# vertex compression is disabled. Bound angular error to ~0.012 degrees.
	const NORMAL_EPSILON: float = 0.0002
	for surface: int in range(instance.mesh.get_surface_count()):
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index: int in range(0, indices.size(), 3):
			var a: int = indices[index]
			var b: int = indices[index + 1]
			var c: int = indices[index + 2]
			var edge: Vector3 = (vertices[b] - vertices[a]).normalized()
			var other: Vector3 = (vertices[c] - vertices[a]).normalized()
			var normal: Vector3 = normals[a]
			if absf(normal.length() - 1.0) > NORMAL_EPSILON or absf(normal.dot(edge)) > NORMAL_EPSILON or absf(normal.dot(other)) > NORMAL_EPSILON:
				return false
			# Godot front faces are clockwise, so their outward normal opposes cross.
			if normal.dot(edge.cross(other)) >= 0.0: return false
			if arrays[Mesh.ARRAY_TANGENT] != null:
				var tangent: Vector3 = Vector3(arrays[Mesh.ARRAY_TANGENT][a * 4], arrays[Mesh.ARRAY_TANGENT][a * 4 + 1], arrays[Mesh.ARRAY_TANGENT][a * 4 + 2])
				if absf(tangent.dot(normal)) > NORMAL_EPSILON or absf(tangent.length() - 1.0) > NORMAL_EPSILON: return false
	return true


func _test_cells_and_guards() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var paint: Material = Surfaces.material("plain", "d4c896")
	_box(fixture, paint, Vector3(1, 1, 1))
	_box(fixture, paint, Vector3(3, 1, 1))
	_box(fixture, paint, Vector3(41, 1, 1))
	var hidden: MeshInstance3D = _box(fixture, paint, Vector3(2, 1, 2))
	hidden.visible = false
	var faded: MeshInstance3D = _box(fixture, paint, Vector3(2, 1, 3))
	faded.visibility_range_end = 10.0
	var custom: MeshInstance3D = _box(fixture, paint, Vector3(2, 1, 4))
	custom.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var transparent: MeshInstance3D = _box(fixture, paint.duplicate() as Material, Vector3(2, 1, 5))
	(transparent.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var metrics: Dictionary = Batcher.batch_children(fixture, 16.0)
	_check(metrics.source_meshes == 3 and metrics.batches == 2, "spatially distant geometry forms a separate bounded batch")
	_check(is_instance_valid(hidden) and not hidden.visible, "hidden source is not accidentally revealed")
	_check(is_instance_valid(faded) and faded.visibility_range_end == 10.0, "per-object visibility range remains independent")
	_check(is_instance_valid(custom) and custom.custom_aabb.size == Vector3(4, 4, 4), "custom culling bounds are not silently discarded")
	_check(is_instance_valid(transparent), "transparent objects retain independent sorting")
	_check(Batcher.batch_children(null).source_meshes == 0, "null batch root is a no-op")
	fixture.free()


func _test_palette_batching() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var palette: Array[String] = ["e8c040", "4a5028", "1a1810", "604020", "d4c896", "8a3a3a", "d06030"]
	for index: int in range(palette.size()):
		_box(fixture, Surfaces.material("plain", palette[index]), Vector3(index * 2, 1, 0))
	# Loft-like custom faces have no UV or tangent channels, unlike BoxMesh. Those
	# channels are unused by plain/triplanar kit materials and must not split them.
	for index: int in range(2):
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, Surfaces.material("plain", palette[index]))
		var face := MeshInstance3D.new()
		face.mesh = mesh
		face.position = Vector3(index * 2, 3, 0)
		fixture.add_child(face)
	var before: Dictionary = _palette_inventory(fixture)
	var metrics: Dictionary = Batcher.batch_children(fixture, 0.0)
	_check(metrics.source_meshes == 9 and metrics.batches == 1 and metrics.palette_surfaces == 9, "seven palette colors across primitives and lofts become one compatible surface")
	_check(before == _palette_inventory(fixture), "every palette color remains attached to its original vertex in sRGB bytes")
	var batch: MeshInstance3D = fixture.get_child(0) as MeshInstance3D
	var paint: StandardMaterial3D = batch.get_active_material(0) as StandardMaterial3D
	_check(paint.vertex_color_use_as_albedo and paint.vertex_color_is_srgb and paint.albedo_color == Color.WHITE, "batched material uses a neutral carrier and correct sRGB vertex interpretation")
	var baked: Array = batch.mesh.surface_get_arrays(0)
	# The engine reconstructs a fallback tangent array alongside packed normals,
	# even if none was submitted. Its existence does not mean a tangent effect is on.
	_check(baked[Mesh.ARRAY_TEX_UV] == null and not paint.normal_enabled and not paint.anisotropy_enabled, "UV-free palette batches do not enable tangent-dependent effects")
	var source: StandardMaterial3D = Surfaces.material("fabric", "4a5028")
	var rough: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	rough.roughness = 0.3
	var two_sided: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	_check(Surfaces.palette_material(source) != Surfaces.palette_material(rough), "different roughness cannot collapse into the same palette material")
	_check(Surfaces.palette_material(source) != Surfaces.palette_material(two_sided), "cull mode remains distinct for thin character clothing")
	_check(Surfaces.palette_material(source).albedo_texture == source.albedo_texture, "palette normalization retains the procedural texture")
	_check(source.albedo_color == Color("4a5028") and not source.vertex_color_use_as_albedo, "palette normalization never mutates cached source materials")
	var emissive: StandardMaterial3D = Surfaces.material("plain", "e8c040", 0.94, 1.0)
	_check(Surfaces.palette_material(emissive) == null, "emission is excluded from palette rewriting")
	var arbitrary := StandardMaterial3D.new()
	arbitrary.albedo_color = Color("8a3a3a")
	_check(Surfaces.palette_material(arbitrary) == null, "arbitrary external materials do not opt into tint rewriting")
	var uv_dependent: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	uv_dependent.uv1_triplanar = false
	_check(Surfaces.palette_material(uv_dependent) == null, "a caller's UV-dependent texture retains its original attributes")
	fixture.free()


func _palette_inventory(node: Node3D) -> Dictionary:
	var result: Dictionary = {}
	if node is MeshInstance3D:
		var instance: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var paint: StandardMaterial3D = instance.get_active_material(surface) as StandardMaterial3D
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index: int in range(vertices.size()):
				var tint: Color = paint.albedo_color
				if paint.vertex_color_use_as_albedo:
					tint *= arrays[Mesh.ARRAY_COLOR][index]
				var position_at: Vector3 = instance.global_transform * vertices[index]
				var key: String = "%.3f,%.3f,%.3f/%s" % [position_at.x, position_at.y, position_at.z, tint.to_html()]
				result[key] = int(result.get(key, 0)) + 1
	for child: Node in node.get_children():
		if child is Node3D:
			var nested: Dictionary = _palette_inventory(child as Node3D)
			for key: String in nested:
				result[key] = int(result.get(key, 0)) + int(nested[key])
	return result
