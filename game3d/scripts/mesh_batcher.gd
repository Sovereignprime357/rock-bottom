class_name SliceMeshBatcher
extends RefCounted
## Construction-time merge of direct static mesh leaves. Put animation and target
## handles on Node3D/physics parents, or set no_batch metadata to retain a leaf.
## Children, scripts, metadata, skinning, LODs and unusual vertex formats are kept.

const STATE_PROPERTIES: Array[String] = [
	"layers", "cast_shadow", "gi_mode", "extra_cull_margin", "ignore_occlusion_culling",
	"lod_bias", "transparency", "visibility_range_begin", "visibility_range_end",
	"visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode",
	"sorting_offset", "sorting_use_aabb_center",
]
const ATTRIBUTE_SLOTS: Array[int] = [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]
const Surfaces = preload("res://scripts/surface_kit.gd")


static func batch_children(root: Node3D, cell_size: float = 16.0) -> Dictionary:
	var metrics: Dictionary = {"source_meshes": 0, "source_surfaces": 0, "batches": 0, "surfaces": 0, "triangles": 0, "vertices": 0, "skipped_meshes": 0, "palette_surfaces": 0}
	if root == null:
		return metrics
	var cells: float = cell_size if is_finite(cell_size) and cell_size > 0.0 else 0.0
	var groups: Dictionary = {}
	var palette_cache: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if not child is MeshInstance3D:
			continue
		var source: MeshInstance3D = child as MeshInstance3D
		if not _eligible(source):
			metrics.skipped_meshes += 1
			continue
		var cell := Vector3i.ZERO
		if cells > 0.0:
			cell = Vector3i(floori(source.position.x / cells), floori(source.position.y / cells), floori(source.position.z / cells))
		var state: Array = [cell, _resource_id(source.material_overlay)]
		for property: String in STATE_PROPERTIES:
			state.append(source.get(property))
		for surface: int in range(source.mesh.get_surface_count()):
			var arrays: Array = source.mesh.surface_get_arrays(surface)
			var paint: Material = source.get_active_material(surface)
			var tint := Color.WHITE
			var palette: bool = false
			var has_colors: bool = arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > 0
			if paint is StandardMaterial3D and not has_colors and source.material_overlay == null:
				var paint_id: int = paint.get_instance_id()
				if not palette_cache.has(paint_id):
					palette_cache[paint_id] = Surfaces.palette_material(paint as StandardMaterial3D)
				var compatible: StandardMaterial3D = palette_cache[paint_id] as StandardMaterial3D
				if compatible != null:
					tint = (paint as StandardMaterial3D).albedo_color
					paint = compatible
					palette = true
					metrics.palette_surfaces += 1
			var layout: Array[int] = []
			for slot: int in ATTRIBUTE_SLOTS:
				if palette and slot in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
					continue
				if palette and slot == Mesh.ARRAY_COLOR:
					layout.append(slot)
					continue
				if arrays[slot] != null and arrays[slot].size() > 0:
					layout.append(slot)
			var key: String = str(state) + "/" + str(_resource_id(paint)) + "/" + str(layout)
			if not groups.has(key):
				groups[key] = {"paint": paint, "template": source, "layout": layout,
					"vertices": [], "normals": [], "tangents": [], "colors": [], "uv": [], "uv2": [], "indices": []}
			_append(groups[key], arrays, source.transform, palette, tint)
			metrics.source_surfaces += 1
		sources.append(source)
	metrics.source_meshes = sources.size()
	for key: String in groups:
		var group: Dictionary = groups[key]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(group.vertices)
		if group.layout.has(Mesh.ARRAY_NORMAL): arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(group.normals)
		if group.layout.has(Mesh.ARRAY_TANGENT): arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array(group.tangents)
		if group.layout.has(Mesh.ARRAY_COLOR): arrays[Mesh.ARRAY_COLOR] = PackedColorArray(group.colors)
		if group.layout.has(Mesh.ARRAY_TEX_UV): arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(group.uv)
		if group.layout.has(Mesh.ARRAY_TEX_UV2): arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(group.uv2)
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(group.indices)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, group.paint)
		var batch := MeshInstance3D.new()
		batch.name = "static_batch_%03d" % int(metrics.batches)
		batch.mesh = mesh
		batch.set_meta("slice_static_batch", true)
		var template: MeshInstance3D = group.template as MeshInstance3D
		for property: String in STATE_PROPERTIES:
			batch.set(property, template.get(property))
		batch.material_overlay = template.material_overlay
		root.add_child(batch)
		metrics.batches += 1
		metrics.surfaces += 1
		metrics.triangles += int(float(group.indices.size()) / 3.0)
		metrics.vertices += group.vertices.size()
	# Only now release sources: group templates are live while all batches are built.
	for source: MeshInstance3D in sources:
		root.remove_child(source)
		source.free()
	return metrics


static func _resource_id(resource: Resource) -> int:
	return resource.get_instance_id() if resource != null else 0


static func _eligible(source: MeshInstance3D) -> bool:
	if source.mesh == null or not source.visible or source.get_child_count() != 0:
		return false
	if source.get_script() != null or not source.get_meta_list().is_empty() or source.is_set_as_top_level():
		return false
	if source.skin != null or source.get_blend_shape_count() != 0 or source.custom_aabb != AABB():
		return false
	if not source.visibility_parent.is_empty() or absf(source.transform.basis.determinant()) < 0.000001:
		return false
	# Per-object fades and alpha sorting cannot be represented by one batch origin.
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0 or source.transparency != 0.0:
		return false
	if not source.mesh is PrimitiveMesh and not source.mesh is ArrayMesh:
		return false
	if source.mesh.get_surface_count() == 0:
		return false
	for surface: int in range(source.mesh.get_surface_count()):
		if source.mesh is ArrayMesh:
			var array_mesh: ArrayMesh = source.mesh as ArrayMesh
			if array_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES or array_mesh.shadow_mesh != null or array_mesh.custom_aabb != AABB():
				return false
			var surface_data: Dictionary = RenderingServer.mesh_get_surface(array_mesh.get_rid(), surface)
			if surface_data.has("lods") and not surface_data["lods"].is_empty():
				return false
		var paint: Material = source.get_active_material(surface)
		if paint is BaseMaterial3D and (paint as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		# Custom shaders may use instance coordinates/parameters in arbitrary ways.
		if paint is ShaderMaterial or source.material_overlay is ShaderMaterial:
			return false
		var arrays: Array = source.mesh.surface_get_arrays(surface)
		if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty():
			return false
		for slot: int in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			if arrays[slot] != null and arrays[slot].size() != 0:
				return false
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
			count = arrays[Mesh.ARRAY_INDEX].size()
		if count % 3 != 0:
			return false
	return true


static func _append(group: Dictionary, arrays: Array, transform_at: Transform3D, palette: bool, tint: Color) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var offset: int = group.vertices.size()
	var normal_basis: Basis = transform_at.basis.inverse().transposed()
	var mirrored: bool = transform_at.basis.determinant() < 0.0
	for index: int in range(vertices.size()):
		group.vertices.append(transform_at * vertices[index])
		var normal := Vector3.ZERO
		if group.layout.has(Mesh.ARRAY_NORMAL):
			normal = (normal_basis * arrays[Mesh.ARRAY_NORMAL][index]).normalized()
			group.normals.append(normal)
		if group.layout.has(Mesh.ARRAY_TANGENT):
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var tangent: Vector3 = transform_at.basis * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
			# Gram-Schmidt keeps the tangent perpendicular under nonuniform scale/shear.
			tangent = (tangent - normal * tangent.dot(normal)).normalized()
			group.tangents.append_array([tangent.x, tangent.y, tangent.z, tangents[index * 4 + 3] * (-1.0 if mirrored else 1.0)])
		if group.layout.has(Mesh.ARRAY_COLOR): group.colors.append(tint if palette else arrays[Mesh.ARRAY_COLOR][index])
		if group.layout.has(Mesh.ARRAY_TEX_UV): group.uv.append(arrays[Mesh.ARRAY_TEX_UV][index])
		if group.layout.has(Mesh.ARRAY_TEX_UV2): group.uv2.append(arrays[Mesh.ARRAY_TEX_UV2][index])
	var indices: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index: int in range(vertices.size()): indices.append(index)
	for index: int in range(0, indices.size(), 3):
		group.indices.append(offset + indices[index])
		group.indices.append(offset + indices[index + (2 if mirrored else 1)])
		group.indices.append(offset + indices[index + (1 if mirrored else 2)])
