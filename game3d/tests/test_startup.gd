extends SceneTree

const Roster = preload("res://scripts/character_roster.gd")
const Startup = preload("res://scripts/startup_presentation.gd")
const Animator = preload("res://scripts/actor_animation.gd")
var checks: int = 0
var failures: Array[String] = []
var compared: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)


func _run() -> void:
	_check(not Roster.prepare(&"unknown_startup_actor") and not Roster.is_prepared(&"unknown_startup_actor"),"unknown preparation cannot create a generic actor")
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	seed(71719)
	var expected_random := randi()
	seed(71719)
	_check(Roster.prepare(&"horsecop") and Roster.is_prepared(&"mounted_rider"),"preparing a mounted identity includes its companion resources")
	_check(Roster.prepare(&"model_family") and Roster.is_prepared(&"model_father") and Roster.is_prepared(&"model_mother") and Roster.is_prepared(&"model_son"),"preparing an assembly includes every independent child template")
	var reference_usec: int = 0
	for name: String in Roster.supported_visuals():
		var id := StringName(name)
		_check(Roster.prepare(id) and Roster.is_prepared(id),name+": immutable resources prepare successfully")
		if not Roster.is_prepared(id): continue
		var cached: Dictionary = Roster._templates[id]
		var reference := Roster._build_template(id,false)
		_check(not reference.is_empty(),name+": uncached reference builder completes")
		if reference.is_empty(): continue
		reference_usec += int(reference.build_stats.build_usec)
		var equal := _templates_equal(cached,reference)
		_check(equal,name+": all final mesh bytes, materials, bones, skin binds and attachments match uncached authoring")
		_check(not cached.has("weight_caches") and not cached.has("groups") and not cached.has("skip"),name+": temporary construction caches are discarded")
		_check(int(cached.build_stats.weight_solves)+int(cached.build_stats.weight_cache_hits) == int(reference.build_stats.weight_solves),name+": cached and uncached builders consume the same exact emitted corners")
		if int(reference.build_stats.weight_solves) > 0:
			_check(int(cached.build_stats.weight_cache_hits) > 0 and int(cached.build_stats.weight_solves) < int(reference.build_stats.weight_solves),name+": repeated exact positions reuse their original influence result")
		var skin: Skin = cached.skin
		var meshes: Array = cached.meshes.duplicate()
		var statistics: Dictionary = cached.build_stats.duplicate()
		_check(Roster.prepare(id) and cached.skin == skin and cached.build_stats == statistics,name+": repeated preparation does not rebuild skin or timing state")
		var shared: bool = true
		for index: int in range(meshes.size()): shared = shared and meshes[index].mesh == Roster._templates[id].meshes[index].mesh
		_check(shared,name+": prepared mesh resources retain identity")
		compared += 1
	_check(compared == 72,"every original authored template completed byte-equivalence comparison")
	_check(randi() == expected_random,"preparation consumes no global random values")
	_check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before,"resource preparation retains no disposable actors, Skeletons or attachment nodes")
	var stats := Roster.preparation_stats()
	_check(stats.templates == 72 and stats.total == 72 and stats.weight_cache_hits > stats.weight_solves,"prepared cast reports complete coverage and measured influence reuse")
	print("STARTUP PREPARE: templates=%d memoized=%.3fms reference=%.3fms solves=%d hits=%d (same-process diagnostic, not cold-Web timing)" % [stats.templates,float(stats.build_usec)/1000.0,float(reference_usec)/1000.0,stats.weight_solves,stats.weight_cache_hits])
	_instance_independence()
	await _presentation()
	if failures.is_empty() and compared == 72:
		print("3D STARTUP GATE: PASS (%d checks;72 exact authored templates, shared immutable resources and opaque progress)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D STARTUP GATE: FAIL (%d / %d checks; %d templates compared)" % [failures.size(),checks,compared])
		quit(1)


func _templates_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.metrics != right.metrics or var_to_bytes(left.bones) != var_to_bytes(right.bones): return false
	if left.meshes.size() != right.meshes.size() or left.attachments.size() != right.attachments.size(): return false
	var left_skin: Skin = left.skin
	var right_skin: Skin = right.skin
	if left_skin.get_bind_count() != right_skin.get_bind_count(): return false
	for index: int in range(left_skin.get_bind_count()):
		if left_skin.get_bind_bone(index) != right_skin.get_bind_bone(index) or var_to_bytes(left_skin.get_bind_pose(index)) != var_to_bytes(right_skin.get_bind_pose(index)): return false
	for index: int in range(left.meshes.size()):
		if left.meshes[index].layer != right.meshes[index].layer or not _meshes_equal(left.meshes[index].mesh,right.meshes[index].mesh): return false
	for index: int in range(left.attachments.size()):
		var a: Dictionary = left.attachments[index]
		var b: Dictionary = right.attachments[index]
		if a.bone != b.bone or var_to_bytes(a.offset) != var_to_bytes(b.offset): return false
		var first := (a.scene as PackedScene).instantiate()
		var second := (b.scene as PackedScene).instantiate()
		var equal := _nodes_equal(first,second)
		first.free(); second.free()
		if not equal: return false
	return true


func _meshes_equal(left: Mesh, right: Mesh) -> bool:
	if left == null or right == null: return left == right
	if left.get_surface_count() != right.get_surface_count(): return false
	for surface: int in range(left.get_surface_count()):
		# Variant encoding retains the packed arrays' exact binary representation;
		# no tolerance or changed vertex ordering can hide in this comparison.
		if var_to_bytes(left.surface_get_arrays(surface)) != var_to_bytes(right.surface_get_arrays(surface)): return false
		if not _materials_equal(left.surface_get_material(surface),right.surface_get_material(surface)): return false
	return true


func _materials_equal(left: Material, right: Material) -> bool:
	if left == right: return true
	if left == null or right == null or left.get_class() != right.get_class(): return false
	for property: Dictionary in left.get_property_list():
		var name: String = property.name
		if (int(property.usage)&PROPERTY_USAGE_STORAGE) == 0 or name.begins_with("resource_") or name.begins_with("metadata/"): continue
		if left.get(name) != right.get(name): return false
	return true


func _nodes_equal(left: Node, right: Node) -> bool:
	# Godot-generated leaf names encode allocation IDs. Explicit authored handles
	# must match; anonymous leaves are compared structurally in original order.
	var generated_names: bool = String(left.name).begins_with("@") and String(right.name).begins_with("@")
	if (left.name != right.name and not generated_names) or left.get_class() != right.get_class() or left.get_child_count() != right.get_child_count(): return false
	if left is Node3D and var_to_bytes(left.transform) != var_to_bytes(right.transform): return false
	if left is MeshInstance3D:
		if not _meshes_equal(left.mesh,right.mesh) or not _materials_equal(left.material_override,right.material_override) or left.cast_shadow != right.cast_shadow: return false
	for index: int in range(left.get_child_count()):
		if not _nodes_equal(left.get_child(index),right.get_child(index)): return false
	return true


func _instance_independence() -> void:
	var first := Roster.create(&"tony",19)
	var second := Roster.create(&"tony",19)
	_check(first != null and second != null,"prepared identities instantiate both actual rigs")
	if first == null or second == null:
		if first != null: first.free()
		if second != null: second.free()
		return
	root.add_child(first); root.add_child(second)
	var rig: Dictionary = first.get_meta("roster_rig")
	var other: Dictionary = second.get_meta("roster_rig")
	var original := _poses(second)
	Animator.tick(first,0.02,{"action":&"strike","action_phase":0.03,"coat_count":0})
	_check(rig.skeleton != other.skeleton and _poses(second) == original and _poses(first) != original,"preparation preserves independent mutable poses")
	var a: MeshInstance3D = rig.layers[0][0]
	var b: MeshInstance3D = other.layers[0][0]
	_check(a.mesh == b.mesh and a.skin == b.skin and first.get_node("head") != second.get_node("head"),"created rigs reuse GPU resources while owning separate attached faces")
	first.free(); second.free()


func _poses(art: Node3D) -> Array[Transform3D]:
	var skeleton := art.get_node("Skeleton") as Skeleton3D
	var result: Array[Transform3D] = []
	for index: int in range(skeleton.get_bone_count()): result.append(skeleton.get_bone_pose(index))
	return result


func _presentation() -> void:
	root.size = Vector2i(1280,720)
	var overlay := Startup.new()
	root.add_child(overlay)
	overlay.show_stage("the block.",0,1)
	await process_frame
	_check(overlay.cover.color.a == 1.0 and overlay.cover.get_global_rect() == root.get_visible_rect(),"startup covers the actual full viewport with alpha-one color")
	_check(overlay.layer > 0 and overlay.cover.mouse_filter == Control.MOUSE_FILTER_STOP,"startup layer covers HUD and blocks pointer delivery")
	overlay.show_stage("the block.",1,1)
	overlay.show_stage("the neighbors.",3,72)
	_check(overlay.progress.visible and overlay.progress.value == 3 and overlay.progress.max_value == 72 and overlay.count_label.text == "3 / 72","loading progress reports actual work counts")
	var timing := overlay.stage_timings()
	_check(timing.size() == 2 and timing[0].stage == "the block." and timing[0].completed == 1 and timing[0].elapsed_usec >= 0,"stage evidence records completed work and monotonic elapsed time")
	timing[0].stage = "mutated"
	_check(overlay.stage_timings()[0].stage == "the block.","timing reports are detached from retained evidence")
	# canvas_items stretch retains a logical canvas distinct from physical window
	# pixels. Change aspect too, then compare coverage in the viewport's own units.
	root.size = Vector2i(960,720)
	await process_frame
	await process_frame
	_check(overlay.cover.get_global_rect() == root.get_visible_rect(),"opaque coverage follows the actual stretched viewport after aspect resize")
	overlay.show_stage("the light.",0,0)
	_check(not overlay.progress.visible and overlay.count_label.text.is_empty(),"unknown totals show no invented percentage")
	overlay.finish()
	var ended := overlay.stage_timings()
	overlay.finish()
	_check(not overlay.cover.visible and overlay.stage_timings() == ended,"finish hides startup exactly once and retains final timing evidence")
	_check(overlay.find_children("*","Node3D",true,false).is_empty(),"startup view creates no full characters or rendering proxies")
	overlay.free()
