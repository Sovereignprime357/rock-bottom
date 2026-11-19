extends SceneTree
## Pure pickup presentation; source visibility is exercised through the real Utilities owner.
const View = preload("res://scripts/find_view.gd")
const State = preload("res://scripts/game_state.gd")
const Utilities = preload("res://scripts/neighborhood_utilities.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _cash(extra: Dictionary = {}) -> Dictionary:
	var result := {"id":"find_fixture","x":1050.0,"y":840.0,"amt":10,"collected":false}
	result.merge(extra,true); return result
func _meshes(view: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in view.find_children("*","MeshInstance3D",true,false): result.append(node as MeshInstance3D)
	return result
func _node_ids(view: Node) -> Array[int]:
	var result: Array[int] = [view.get_instance_id()]
	for node: Node in view.find_children("*","",true,false): result.append(node.get_instance_id())
	return result
func _material_state(material: Material) -> Dictionary:
	if material == null: return {}
	var result := {"id":material.get_instance_id()}
	if material is StandardMaterial3D:
		for key: String in ["albedo_color","roughness","metallic","emission_enabled","emission","emission_energy_multiplier","vertex_color_use_as_albedo","cull_mode","transparency","uv1_scale","uv1_triplanar","uv1_world_triplanar","texture_filter"]:
			result[key] = material.get(key)
		var texture: Texture2D = material.albedo_texture
		result.texture = texture.get_instance_id() if texture != null else 0
		if texture != null and texture.get_image() != null: result.texture_pixels = hash(texture.get_image().get_data())
	return result
func _resources(view: Node) -> Dictionary:
	var result: Dictionary = {}
	for instance: MeshInstance3D in _meshes(view):
		if instance.mesh == null: continue
		var surfaces: Array = []
		for surface: int in range(instance.mesh.get_surface_count()):
			surfaces.append([hash(instance.mesh.surface_get_arrays(surface)),_material_state(instance.get_active_material(surface))])
		result[instance.mesh.get_instance_id()] = surfaces
	return result
func _ownership(view: Node3D,label: String) -> void:
	var nodes: Array[Node] = [view]; nodes.append_array(view.find_children("*","",true,false))
	for node: Node in nodes:
		_check(not node is CollisionObject3D and not node is CollisionShape3D and not node is Timer and not node is Light3D and not node is AudioStreamPlayer and not node is Camera3D,label+" has no gameplay/collision/timer/light/audio owner")
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input() and not node.is_processing_unhandled_input() and not node.is_processing_unhandled_key_input(),label+" has no active frame/input callback")
func _geometry(view: Node3D,label: String) -> void:
	var bounds := AABB(); var started: bool = false
	var valid: bool = true; var fronts: bool = true; var materials: bool = true
	var triangles: int = 0; var surfaces: int = 0; var vertices_count: int = 0
	var inverse: Transform3D = view.global_transform.affine_inverse()
	for instance: MeshInstance3D in _meshes(view):
		if instance.mesh == null: valid = false; continue
		var transform: Transform3D = inverse*instance.global_transform
		for surface: int in range(instance.mesh.get_surface_count()):
			surfaces += 1
			materials = materials and instance.get_active_material(surface) is StandardMaterial3D
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				valid = false; continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			valid = valid and vertices.size() == normals.size()
			vertices_count += vertices.size()
			for index: int in range(vertices.size()):
				var at: Vector3 = transform*vertices[index]
				valid = valid and at.is_finite()
				if index < normals.size(): valid = valid and normals[index].is_finite() and absf(normals[index].length()-1.0) < 0.001
				bounds = bounds.expand(at) if started else AABB(at,Vector3.ZERO); started = true
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			valid = valid and count%3 == 0; triangles += count/3
			for offset: int in range(0,count-2,3):
				var a: int = indices[offset] if not indices.is_empty() else offset
				var b: int = indices[offset+1] if not indices.is_empty() else offset+1
				var c: int = indices[offset+2] if not indices.is_empty() else offset+2
				if mini(a,mini(b,c)) < 0 or maxi(a,maxi(b,c)) >= mini(vertices.size(),normals.size()): valid = false; continue
				var cross: Vector3 = (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
				if cross.length_squared() <= 0.0000000000000001: continue
				var front: Vector3 = -cross.normalized()
				fronts = fronts and normals[a].dot(front) > 0.0 and normals[b].dot(front) > 0.0 and normals[c].dot(front) > 0.0
	_check(started and vertices_count > 0 and valid and fronts,label+" actual mesh vertices/normals are finite, unit and front-facing")
	_check(triangles > 0 and triangles <= 1500 and surfaces > 0 and surfaces <= 4,label+" remains within1500triangle/4surface budget")
	_check(materials,label+" uses native standard palette materials")
	_check(bounds.position.y >= -0.0001 and bounds.end.y <= 0.6501 and bounds.size.x <= 0.6501 and bounds.size.z <= 0.6501,label+" actual geometry is grounded and within65cm")
	_ownership(view,label)
func _model_snapshot(game: RefCounted) -> Dictionary:
	return {"p":game.p.duplicate(true),"s":game.s.duplicate(true),"npcs":game.npcs.duplicate(true),"cash":game.cash_piles.duplicate(true),"events":game.events.duplicate(true),"rng":game.rng_seed}

func _factories() -> void:
	seed(77129); var expected_random: float = randf(); seed(77129)
	var cash: View = View.create_cash(); var crown: View = View.create_crown()
	for view: View in [cash,crown]:
		_check(view.get_parent() == null and not view.visible and not view.is_inside_tree(),"factory returns hidden unparented instance")
		_check(view.get_node_or_null("Art") is Node3D,"factory exposes stable Art child")
		root.add_child(view)
	for extra: Dictionary in [{},{"tool":"propane_torch"},{"equip":"priest_collar"}]: cash.project_cash(_cash(extra),true)
	crown.project_crown({"x":1050.0,"y":840.0,"collected":false})
	_check(randf() == expected_random,"all cold templates/factories/projections leave global RNG untouched")
	cash.free(); crown.free(); groups += 1

func _variants() -> void:
	var view: View = View.create_cash(); root.add_child(view)
	var rows: Array[Dictionary] = [
		{"extra":{},"kind":"money"},{"extra":{"intro":true},"kind":"money"},
		{"extra":{"isInheritance":true,"amt":500},"kind":"money"},{"extra":{"id":"cp_brendan_fixture","amt":30},"kind":"money"},
		{"extra":{"id":"cp_phone_church_fixture","intro":false},"kind":"money"},{"extra":{"id":"cp_park_night_9"},"kind":"money"},
		{"extra":{"tool":"propane_torch"},"kind":"propane_torch"},{"extra":{"equip":"priest_collar"},"kind":"priest_collar"},
		{"extra":{"tool":"propane_torch","equip":"priest_collar"},"kind":"propane_torch"},
		{"extra":{"tool":"unknown","equip":"priest_collar"},"kind":"priest_collar"},
		{"extra":{"tool":"crowbar"},"kind":"money"},{"extra":{"equip":"pigeon_crown"},"kind":"money"},
		{"extra":{"tool":true,"equip":"unknown"},"kind":"money"},{"extra":{"tool":123,"equip":{"bad":true}},"kind":"money"}]
	var templates: Dictionary = {}
	for row: Dictionary in rows:
		var record: Dictionary = _cash(row.extra); var before: Dictionary = record.duplicate(true)
		_check(view.project_cash(record,true) and view.visible and view.presentation_kind == row.kind and view.source_id == record.id,"source tag priority/fallback: "+str(row.extra))
		_check(record == before and view.global_position.is_equal_approx(Content.to_world(Vector2(record.x,record.y))),"projection preserves source and maps exact ground coordinates")
		if not templates.has(row.kind): templates[row.kind] = _resources(view); _geometry(view,row.kind)
		else: _check(_resources(view) == templates[row.kind],"narrative flags/amounts and repeated kind reuse original template")
		_check(view.project_cash(record,false) and not view.visible,"valid supplied-hidden record succeeds without visibility override")
		record.collected = true
		_check(view.project_cash(record,true) and not view.visible,"collected cash remains hidden even when caller visibility is true")
	var missing: Dictionary = _cash(); missing.erase("collected")
	_check(view.project_cash(missing,true) and view.visible,"cash missing collected retains source uncollected default")
	view.free(); groups += 1

func _crown_and_invalid() -> void:
	var cash: View = View.create_cash(); var crown: View = View.create_crown(); root.add_child(cash); root.add_child(crown)
	var record := {"x":1050.0,"y":840.0,"collected":false,"quest_done":true}
	_check(crown.project_crown(record) and crown.visible and crown.presentation_kind == "crown","separate existing uncollected crown ignores extra quest flags")
	_geometry(crown,"crown")
	_check(crown.project_crown({"x":1050,"y":840}) and not crown.visible,"crown missing collected defaults hidden exactly as Scene")
	_check(crown.project_crown({"x":1050,"y":840,"collected":true}) and not crown.visible,"collected crown remains structurally valid and hidden")
	for bad: Dictionary in [{},{"id":"","x":1,"y":2},{"id":12,"x":1,"y":2},{"id":true,"x":1,"y":2},{"id":"bad","x":"1","y":2},{"id":"bad","x":true,"y":2},{"id":"bad","x":1},{"id":"bad","x":NAN,"y":2},{"id":"bad","x":1,"y":INF},{"id":"bad","x":1.0e100,"y":2}]:
		cash.project_cash(_cash(),true); var before: String = JSON.stringify(bad)
		_check(not cash.project_cash(bad,true) and not cash.visible and JSON.stringify(bad) == before,"malformed cash hides immediately without source repair")
		_check(cash.project_cash(_cash(),true) and cash.visible,"valid cash recovers after malformed row")
	for bad: Variant in [null,false,[],{},"crown",{"x":1},{"x":"1","y":2},{"x":NAN,"y":2},{"x":1,"y":INF},{"x":1.0e100,"y":2}]:
		crown.project_crown(record); var before: String = JSON.stringify(bad)
		_check(not crown.project_crown(bad) and not crown.visible and JSON.stringify(bad) == before,"malformed crown hides without retaining previous item")
		_check(crown.project_crown(record) and crown.visible,"valid crown recovers after malformed row")
	cash.project_cash(_cash(),true)
	_check(not cash.project_crown(record) and not cash.visible,"crown call on cash instance fails closed")
	crown.project_crown(record)
	_check(not crown.project_cash(_cash(),true) and not crown.visible,"cash call on crown instance fails closed")
	cash.free(); crown.free(); groups += 1

func _cache_and_detachment() -> void:
	var first: View = View.create_cash(); var other: View = View.create_cash(); root.add_child(first); root.add_child(other)
	var record: Dictionary = _cash(); first.project_cash(record,true); other.project_cash(record,true)
	var resources: Dictionary = _resources(first); var nodes: Array[int] = _node_ids(first)
	var other_nodes: Array[int] = _node_ids(other); var other_pose: Transform3D = other.transform
	_check(resources == _resources(other) and nodes != other_nodes,"independent instances share only immutable mesh/material resources")
	var point: Vector3 = first.position; record.x += 100; record.tool = "propane_torch"; record.id = "mutated_after_projection"
	_check(first.position == point and first.presentation_kind == "money" and first.source_id == "find_fixture" and _node_ids(first) == nodes,"caller dictionary mutation cannot change retained identity/transform/art")
	for index: int in range(25):
		var moved: Dictionary = _cash({"x":1050+index,"id":"cash_%d"%index,"amt":index*100,"intro":index%2 == 0})
		_check(first.project_cash(moved,index%3 != 0) and _node_ids(first) == nodes and _resources(first) == resources,"same-kind projection changes no nodes/resources/materials")
	_check(other.transform == other_pose and other.visible and _node_ids(other) == other_nodes and _resources(other) == resources,"one instance cannot move/hide/mutate another")
	var art: Node = first.get_node("Art")
	_check(first.project_cash(_cash({"tool":"propane_torch"}),true) and first.presentation_kind == "propane_torch" and first.get_node("Art") == art and _node_ids(first) != nodes,"same-ID kind change replaces only cached Art leaves")
	_check(_resources(other) == resources,"type replacement leaves prior shared template immutable")
	first.project_cash(_cash(),true)
	_check(_resources(first) == resources,"returning to previous kind reuses original template resources")
	var crown: View = View.create_crown(); var second_crown: View = View.create_crown(); root.add_child(crown); root.add_child(second_crown)
	crown.project_crown({"x":1050,"y":840,"collected":false}); second_crown.project_crown({"x":1060,"y":840,"collected":false})
	_check(_resources(crown) == _resources(second_crown),"separate crown instances reuse cached immutable resources")
	var crown_nodes: Array[int] = _node_ids(crown); var crown_resources: Dictionary = _resources(crown)
	crown.project_crown({"x":1070,"y":850,"collected":true})
	_check(_node_ids(crown) == crown_nodes and _resources(crown) == crown_resources and second_crown.visible,"crown movement/collection does not rebuild or cross instance visibility")
	first.free(); other.free(); crown.free(); second_crown.free(); groups += 1

func _utilities_visibility() -> void:
	var game := State.new(); var utilities := Utilities.new(game,null); var view: View = View.create_cash(); root.add_child(view)
	game.p.x = 1050-float(game.p.w)*0.5; game.p.y = 840-float(game.p.h)*0.5; game.s.tweakerT = 0.0
	var rows: Array[Dictionary] = [
		{"extra":{"x":1109.999},"visible":true},{"extra":{"x":1110.0},"visible":false},{"extra":{"x":1250.0},"visible":false},
		{"extra":{"x":1250.0,"intro":true},"visible":true},{"extra":{"x":1250.0,"tool":"propane_torch"},"visible":true},
		{"extra":{"x":1250.0,"tool":"unknown"},"visible":true},{"extra":{"x":1250.0,"equip":"priest_collar"},"visible":true},
		{"extra":{"x":1250.0,"equip":"unknown"},"visible":true},{"extra":{"x":1250.0,"tool":false,"equip":""},"visible":false},
		{"extra":{"x":1250.0,"intro":true,"collected":true},"visible":false}]
	for row: Dictionary in rows:
		var record: Dictionary = _cash(row.extra); var before: Dictionary = _model_snapshot(game)
		var shown: bool = utilities.cash_visible(record)
		_check(shown == row.visible and view.project_cash(record,shown) and view.visible == shown,"actual Utilities strict60/intro/tag/collected visibility: "+str(row.extra))
		_check(_model_snapshot(game) == before,"Utilities/view projection changes no gameplay clock, RNG, cash, actors or events")
	game.s.tweakerT = 1.0; var distant: Dictionary = _cash({"x":1250.0})
	_check(utilities.cash_visible(distant) and view.project_cash(distant,true) and view.visible,"active source vision reveals distant money")
	var before: Dictionary = _model_snapshot(game)
	_check(view.project_cash(distant,false) and not view.visible,"view honors supplied false even when actual source vision is active")
	game.s.tweakerT = 0.0; before = _model_snapshot(game)
	_check(not utilities.cash_visible(distant) and view.project_cash(distant,true) and view.visible,"view honors supplied true without inventing distance authority")
	_check(_model_snapshot(game) == before,"visibility overrides remain pure presentation")
	_ownership(view,"live Utilities projection")
	view.free(); groups += 1

func _run() -> void:
	_factories(); _variants(); _crown_and_invalid(); _cache_and_detachment(); _utilities_visibility()
	_check(groups == 5,"all factory/variant/geometry/invalid/cache/visibility paths completed")
	await process_frame
	if failures.is_empty(): print("3D FIND VIEW GATE: PASS (%d checks;4cached kinds/source visibility/no authority)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FIND VIEW GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
