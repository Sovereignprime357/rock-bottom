extends SceneTree
const Leash = preload("res://scripts/dog_leash_view.gd")
const Border = preload("res://scripts/district_border_view.gd")
const Roster = preload("res://scripts/character_roster.gd")
const Animator = preload("res://scripts/actor_animation.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) < 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	return a == b
func _snapshot(dog: Dictionary = {"id":"scrap_dog","dead":false}) -> Dictionary:
	return {"post_present":true,"dog":dog,"post_position":Vector3(0,0.62,0),"collar_position":Vector3(1.3,0.5,0.8)}
func _pools(view: Leash) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for child: Node in view.get_children():
		if child is MultiMeshInstance3D: result.append(child as MultiMeshInstance3D)
	return result
func _resources(view: Leash) -> Array:
	var result: Array = []
	for pool: MultiMeshInstance3D in _pools(view): result.append([pool,pool.multimesh,pool.multimesh.mesh,pool.material_override,pool.multimesh.instance_count])
	return result
func _oracle(fixture: Dictionary,leash: Leash,border: Border) -> void:
	_check(int(fixture.counts.border) == 20 and fixture.border.size() == 20 and int(fixture.counts.leash) == 11 and fixture.leash.size() == 11,"complete unchanged-source oracle census")
	for row: Dictionary in fixture.border:
		var previous: Dictionary = row.previous.duplicate(true); var zone: Dictionary = row.current_zone if row.current_zone is Dictionary else {}
		var zone_before: Dictionary = zone.duplicate(true)
		var expected: Dictionary = row.expected
		if row.call:
			var actual: Dictionary = Border.advance(previous,row.territory_zone_id,zone,row.delta_ms)
			_check(_same(actual,expected),"exact source border decrement/transition: "+row.id)
		else:
			_check(_same(previous,expected),"paused caller retains fields without invoking timing helper")
		_check(previous == row.previous and zone == zone_before,"pure border calculation preserves both caller dictionaries")
		var visible_rect: bool = not expected.borderGlowRect.is_empty()
		_check(border.sync({"remaining_ms":expected.borderGlowT,"color":expected.borderGlowColor,"visible":visible_rect}),"source border snapshot accepted")
		var drawn: Dictionary = border.inspect()
		_check(drawn.visible == row.draw.visible and _same(drawn.alpha,row.draw.alpha) and drawn.width == 3,"source border display alpha/width/gate: "+row.id)
		if row.draw.visible: _check(drawn.color == row.draw.color,"source destination/fallback color: "+row.id)
	for row: Dictionary in fixture.leash:
		var snapshot: Dictionary = _snapshot(row.dog); snapshot.post_present = row.post_present
		_check(leash.sync(snapshot) and leash.inspect().active == row.drawn,"source living exact-id leash gate: "+row.id)
		_check(row.rngDraws == 0 and row.strokes.size() == (2 if row.drawn else 0) and row.dots.size() == (5 if row.drawn else 0),"source chain drawing witnesses remain unchanged")
func _leash(first: Leash,second: Leash) -> void:
	var pools: Array[MultiMeshInstance3D] = _pools(first); var other: Array[MultiMeshInstance3D] = _pools(second)
	_check(pools.size() == 2 and other.size() == 2,"exactly two fixed leash draws")
	for index: int in range(pools.size()):
		_check(pools[index].multimesh != other[index].multimesh and pools[index].multimesh.mesh == other[index].multimesh.mesh and pools[index].material_override == other[index].material_override,"private instance transforms with shared immutable mesh/material")
		_check(pools[index].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"chain casts no dynamic shadows")
	_check(pools[0].multimesh.instance_count == 6 and pools[1].multimesh.instance_count == 5,"six segments and five links remain fixed")
	var resources: Array = _resources(first); var snapshot: Dictionary = _snapshot(); var before: Dictionary = snapshot.duplicate(true)
	first.sync(snapshot); second.sync(_snapshot({"id":"scrap_dog","dead":false,"hidden":true,"chained":false}))
	var other_points: PackedVector3Array = second.inspect().points
	var points: PackedVector3Array = first.inspect().points
	_check(points.size() == 7 and first.to_global(points[0]).distance_to(snapshot.post_position) < 0.00001 and first.to_global(points[6]).distance_to(snapshot.collar_position) < 0.00001,"chain meets both actual supplied endpoints")
	var bounded: bool = true
	for index: int in range(points.size()):
		var straight: Vector3 = Vector3(snapshot.post_position).lerp(snapshot.collar_position,float(index)/6.0)
		bounded = bounded and points[index].is_finite() and points[index].y <= straight.y+0.00001 and straight.y-points[index].y <= 0.16001
	_check(bounded,"sag stays downward within16cm")
	var writes: int = first.inspect().transform_writes
	for index: int in range(50): first.sync(snapshot)
	_check(first.inspect().transform_writes == writes and snapshot == before,"unchanged source endpoints do not rewrite transforms or model")
	points[0] = Vector3(99,99,99); _check(first.inspect().points[0] != points[0],"inspect points are detached")
	first.position = Vector3(2,0.1,-3); first.rotation.y = 0.6; first.sync(snapshot)
	var moved: PackedVector3Array = first.inspect().points
	_check(first.to_global(moved[0]).distance_to(snapshot.post_position) < 0.0001 and first.to_global(moved[6]).distance_to(snapshot.collar_position) < 0.0001 and first.inspect().transform_writes == writes+11,"changed parent transform reprojects global endpoints into local space")
	_check(second.inspect().points == other_points,"another view retains independent chain geometry")
	for dog: Dictionary in [{},{"id":"scrap_dog","dead":true},{"id":"freed_dog_follower","dead":false},{"id":"paisley","dead":false}]:
		_check(first.sync({"post_present":true,"dog":dog}) and not first.inspect().active,"absent/dead/wrong dog clears without endpoint dependencies")
	_check(first.sync({"post_present":false,"dog":{"id":"scrap_dog","dead":false}}) and not first.inspect().active,"missing post clears without endpoints")
	for bad: Dictionary in [{},{"post_present":true,"dog":[]},{"post_present":true,"dog":{"id":"scrap_dog","dead":false}},{"post_present":true,"dog":{"id":"scrap_dog","dead":false},"post_position":Vector3(INF,0,0),"collar_position":Vector3.ZERO}]:
		first.sync(snapshot); _check(not first.sync(bad) and not first.visible,"malformed active endpoint clears prior chain")
	var coincident: Dictionary = _snapshot(); coincident.collar_position = coincident.post_position
	_check(first.sync(coincident) and not first.inspect().active,"finite coincident endpoints hide zero-length chain")
	first.clear(); _check(_resources(first) == resources and first.inspect().queries == 0 and first.inspect().dynamic_shadows == 0,"clear preserves pooled resources without physics or shadows")
func _skin_point(part: MeshInstance3D,surface: int,index: int) -> Vector3:
	var arrays: Array = part.mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]; var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]; var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var skeleton: Skeleton3D = part.get_node(part.skeleton); var point := Vector3.ZERO
	for slot: int in range(4):
		var binding: int = bones[index*4+slot]
		point += (skeleton.get_bone_global_pose(part.skin.get_bind_bone(binding))*part.skin.get_bind_pose(binding)*vertices[index])*weights[index*4+slot]
	return part.global_transform*point
func _collar() -> void:
	var dog: Node3D = Roster.create(&"scrap_dog"); root.add_child(dog)
	var marker: Node3D = dog.get_node_or_null("leash_collar")
	_check(marker != null,"original dog visual exposes weighted collar marker")
	if marker == null: dog.free(); return
	var selected: Dictionary = {}; var nearest: float = INF; var resources: Array = []
	for node: Node in dog.find_children("*","MeshInstance3D",true,false):
		var part: MeshInstance3D = node as MeshInstance3D; resources.append([part,part.mesh,part.skin])
		if part.skin == null: continue
		for surface: int in range(part.mesh.get_surface_count()):
			var count: int = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
			for index: int in range(count):
				var distance: float = _skin_point(part,surface,index).distance_to(marker.global_position)
				if distance < nearest: nearest = distance; selected = {"part":part,"surface":surface,"index":index}
	_check(nearest < 0.0001 and not selected.is_empty(),"rest marker lies on an actual final skinned mesh vertex")
	if not selected.is_empty():
		var original: Vector3 = marker.global_position; var moved: float = 0.0
		for pose: Dictionary in [{"local_velocity":Vector3.ZERO,"action":&"talk","action_phase":0.2},{"local_velocity":Vector3(0,0,1.1),"action":&"","action_phase":0.0},{"local_velocity":Vector3.ZERO,"hurt":0.8,"action":&"bite","action_phase":0.4}]:
			dog.rotation.y += 0.47; Animator.tick(dog,0.1,pose,0)
			var actual: Vector3 = _skin_point(selected.part,selected.surface,selected.index)
			_check(actual.distance_to(marker.global_position) < 0.0001,"collar follows the same actual weighted vertex through idle/yaw/walk/hurt")
			moved = maxf(moved,marker.global_position.distance_to(original))
		_check(moved > 0.01,"weighted collar exercise changes a real pose")
	for row: Array in resources: _check(row[0].mesh == row[1] and row[0].skin == row[2],"collar animation preserves original mesh and skin resources")
	var brutus: Node3D = Roster.create(&"brutus"); _check(not brutus.has_node("leash_collar"),"unrelated dog model gains no leash attachment"); brutus.free(); dog.free()
func _border(border: Border,tint: ColorRect) -> void:
	var original: Color = tint.color
	_check(border.mouse_filter == Control.MOUSE_FILTER_IGNORE and not border.is_processing() and not border.is_processing_input(),"border never owns input or a timer")
	for size: Vector2 in [Vector2(800,600),Vector2(1280,720),Vector2(1920,1080)]:
		border.size = size; border.sync({"remaining_ms":300,"color":"#a04848","visible":true})
		_check(border.size == size and border.inspect().width == 3 and _same(border.inspect().alpha,0.275) and tint.color == original,"resize keeps3px perimeter separate from parent high/crash tint")
	for bad: Dictionary in [{},{"remaining_ms":INF,"color":"#a04848","visible":true},{"remaining_ms":600,"color":"#00ff00","visible":true}]:
		_check(not border.sync(bad) and not border.visible,"malformed border snapshot clears without tint mutation")
	for previous: Dictionary in [{"borderGlowT":NAN},{"lastZoneId":42},{"borderGlowRect":[]},{"borderGlowColor":true}]: _check(Border.advance(previous,null,{},16).is_empty(),"pure timing helper rejects malformed source fields")
	_check(Border.advance({},null,{},INF).is_empty() and Border.advance({},null,{},-1).is_empty(),"invalid accepted-step input is refused")
	border.clear(); _check(tint.color == original,"border clear cannot erase another owner's tint")
func _run() -> void:
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/leash_border_reference.json"))
	if not fixture is Dictionary: push_error("Missing leash/border unchanged-source fixture."); quit(1); return
	seed(91027); var expected_random: int = randi(); seed(91027)
	var leash: Leash = Leash.create(); var other: Leash = Leash.create(); root.add_child(leash); root.add_child(other)
	var tint := ColorRect.new(); tint.color = Color(0.35,0.17,0.36,0.09); root.add_child(tint)
	var border := Border.new(); tint.add_child(border)
	_oracle(fixture,leash,border); _leash(leash,other); _border(border,tint)
	_check(randi() == expected_random,"creating/projecting leash and border never consumes gameplay RNG")
	_collar()
	for node: Node in [leash,other,border]: _check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input(),"presentation has no autonomous work")
	leash.free(); other.free(); tint.free(); await process_frame
	if failures.is_empty(): print("3D LEASH BORDER GATE: PASS (%d checks)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D LEASH BORDER GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
