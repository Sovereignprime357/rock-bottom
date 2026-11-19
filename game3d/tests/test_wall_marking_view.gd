extends SceneTree
## Real authored facades plus detached source layouts; no Runtime or generation in the view.
const View = preload("res://scripts/wall_marking_view.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Content = preload("res://scripts/content_catalog.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _ids(node: Node) -> Array[int]:
	var result: Array[int] = [node.get_instance_id()]
	for child: Node in node.find_children("*","",true,false): result.append(child.get_instance_id())
	return result
func _face(surfaces: Array,row: Dictionary) -> Dictionary:
	for entry: Dictionary in surfaces:
		if entry.building_index == row.building_index: return entry.faces[row.face]
	return {}
func _source(surfaces: Array,row: Dictionary) -> Dictionary:
	for entry: Dictionary in surfaces:
		if entry.building_index == row.building_index: return entry.source
	return {}
func _has_point(rect: Rect2,point: Vector2) -> bool:
	return point.x >= rect.position.x-0.0005 and point.x <= rect.end.x+0.0005 and point.y >= rect.position.y-0.0005 and point.y <= rect.end.y+0.0005
func _geometry(view: View,surfaces: Array,label: String) -> void:
	var info: Dictionary = view.inspect()
	for row: Dictionary in info.records:
		var face: Dictionary = _face(surfaces,row); var inside: bool = false
		for panel: Rect2 in face.panels:
			inside = inside or View._contains(panel.grow(-0.059),row.bounds)
		_check(inside,label+" stays on an actual authored wall panel")
		for blocked: Rect2 in face.keepouts: _check(not row.bounds.intersects(blocked.grow(0.009)),label+" avoids aperture/window/sign envelope")
		if row.face == "bottom":
			var bays: int = maxi(1,int(float(face.span.x)/2.8))
			for bay: int in range(bays):
				var pier := Rect2(float(bay)*float(face.span.x)/float(bays)-0.10,0,0.20,float(face.span.y))
				_check(not row.bounds.intersects(pier),label+" complete glyph envelope avoids every actual projecting pier")
		var holder: Node3D = view.get_node(row.kind+"_"+str(row.index))
		_check(holder.transform.is_finite() and holder.scale.x > 0 and holder.scale.x <= 1.0001,label+" has bounded finite orientation/scale")
		var inverse: Transform3D = (face.transform as Transform3D).affine_inverse()
		var found: bool = false
		for child: Node in holder.get_children():
			if not child is GeometryInstance3D: continue
			found = true
			_check(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,label+" flat art casts no shadow")
			var bounds: AABB = child.get_aabb()
			_check(bounds.size.length() > 0.00001,label+" actual deferred geometry bounds are available")
			if bounds.size.length() < 0.00001: continue
			var contained: bool = true
			for corner: int in range(8):
				var at: Vector3 = inverse*child.global_transform*bounds.get_endpoint(corner)
				contained = contained and at.is_finite() and _has_point(row.bounds,Vector2(at.x,at.y)) and absf(at.z) < 0.025
			_check(contained,label+" actual text/paper geometry lies inside audited rotated envelope")
			if row.face == "bottom" and child is Label3D and row.kind == "graffiti":
				var source: Dictionary = _source(surfaces,row)
				var wall_z: float = Content.to_world(Vector2(source.x,source.y+source.h)).z
				var pigment_outset: float = child.global_position.z-wall_z
				_check(pigment_outset >= 0.0099 and pigment_outset <= 0.0121,label+" ink stays10–12mm from flat wall even when fitted")
		_check(found,label+" has rendered text or paper")
		if row.kind == "poster":
			var paper: MeshInstance3D = holder.get_child(0)
			var paper_width: float = paper.scale.x
			var source: Dictionary = row.source
			_check(paper_width+0.00001 >= float(source.w)*0.04,label+" paper is never narrower than source")
			var lines: PackedStringArray = source.text.split("\n"); var labels: Array = []
			for child: Node in holder.get_children():
				if child is Label3D: labels.append(child)
			_check(labels.size() == lines.size(),label+" retains every source poster line")
			for index: int in range(labels.size()):
				var text: Label3D = labels[index]
				_check(text.text == lines[index] and text.position.x+text.font.get_string_size(text.text,HORIZONTAL_ALIGNMENT_LEFT,-1,text.font_size).x*text.pixel_size <= paper_width*0.5-0.079,label+" unchanged text fits expanded paper with padding")
	for node: Node in view.find_children("*","",true,false):
		_check(not node is CollisionObject3D and not node is CollisionShape3D and not node is Light3D and not node is Timer,label+" owns no physics/light/timer")
		_check(not node.is_processing() and not node.is_physics_processing() and not node.is_processing_input(),label+" has no autonomous tick/input")
func _snapshot(graffiti: Variant,posters: Variant) -> Dictionary:
	return {"graffiti":graffiti,"posters":posters,"revision":1}
func _longest_fronts(surfaces: Array) -> Array[Dictionary]:
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/courier_canvas_metrics.json"))
	var result: Array[Dictionary] = []
	for entry: Dictionary in surfaces:
		var source: Dictionary = entry.source; var chosen: Dictionary = {}
		for line: Dictionary in metrics.entries:
			if line.ceil <= source.w-12 and (chosen.is_empty() or line.ceil > chosen.ceil): chosen = line
		if chosen.is_empty(): continue
		result.append({"x":source.x+6,"y":source.y+source.h-16,"text":chosen.text,"sz":chosen.size,"textW":chosen.ceil,"wallX":source.x+6,"wallW":source.w-12,"wallKind":"bottom","layoutV":2,"col":"#a08070","rot":-0.09 if result.size()%2 == 0 else 0.09})
	return result
func _run() -> void:
	var world: World = World.new(); root.add_child(world); world.build()
	var before := {"obstacles":world.obstacle_records().duplicate(true),"apertures":world.aperture_witnesses.duplicate(true),"structures":world.structure_witnesses.duplicate(true),"adaptations":world.presentation_adaptations.duplicate(),"nodes":_ids(world)}
	var surfaces: Array = world.wall_marking_surfaces()
	_check(surfaces.size() == Content.load_content().buildings.size(),"all25 source buildings have real facade mappings")
	_check(before == {"obstacles":world.obstacle_records(),"apertures":world.aperture_witnesses,"structures":world.structure_witnesses,"adaptations":world.presentation_adaptations,"nodes":_ids(world)},"facade survey creates or mutates no authored geometry")
	for entry: Dictionary in surfaces:
		var origin: Vector3 = Content.to_world(Vector2(entry.source.x,entry.source.y))
		_check(entry.faces.bottom.transform.basis.z.dot(Vector3.BACK) > 0.999 and entry.faces.leftside.transform.basis.z.dot(Vector3.LEFT) > 0.999 and entry.faces.rightside.transform.basis.z.dot(Vector3.RIGHT) > 0.999,"all three source wall kinds face outward")
		_check(entry.faces.leftside.transform.origin.z == origin.z and is_equal_approx(entry.faces.rightside.transform.origin.z,origin.z+float(entry.source.h)*0.04),"side-face normalized coordinates start at the authored ends")
		var wall_z: float = origin.z+float(entry.source.h)*0.04
		_check(absf(float(entry.faces.bottom.transform.origin.z)-wall_z-0.006) < 0.00003,"front marking anchor sits6mm from the real flat wall")
		var bays: int = maxi(1,int(float(entry.faces.bottom.span.x)/2.8))
		for bay: int in range(bays):
			var pier := Rect2(float(bay)*float(entry.faces.bottom.span.x)/float(bays)-0.10,0,0.20,float(entry.faces.bottom.span.y))
			_check(entry.faces.bottom.keepouts.has(pier),"read-only contract includes every authored full-height pier")
	var detached: Array = world.wall_marking_surfaces(); detached[0].source.x = -999; detached[0].faces.bottom.keepouts.clear()
	_check(world.wall_marking_surfaces() == surfaces,"facade return values are detached from source/geometry")
	var first: View = View.create(); var second: View = View.create(); world.add_child(first); world.add_child(second)
	var initial: Dictionary = Content.load_content().initial.state
	var snapshot: Dictionary = _snapshot(initial.graffiti.duplicate(true),initial.posters.duplicate(true)); var saved: Dictionary = snapshot.duplicate(true)
	seed(142857); var expected_random: int = randi(); seed(142857)
	_check(first.sync(snapshot,surfaces),"captured source layout projects")
	await process_frame
	var info: Dictionary = first.inspect()
	_check(info.requested == 23 and info.placed == 23 and info.rejected.is_empty(),"all17 original tags and6 posters visibly accounted for")
	_geometry(first,surfaces,"exported layouts")
	var ids: Array[int] = _ids(first); var builds: int = info.builds
	for index: int in range(24): snapshot.revision += 1; first.sync(snapshot,surfaces)
	_check(_ids(first) == ids and first.inspect().builds == builds,"revision-only empty source retries preserve every existing node")
	snapshot.revision = saved.revision
	_check(snapshot == saved and randi() == expected_random,"projection preserves all source fields and consumes no RNG")
	_check(second.sync(snapshot,surfaces),"independent second presentation")
	var second_ids: Array[int] = _ids(second)
	first.clear(); _check(_ids(second) == second_ids and second.inspect().placed == 23,"clearing one view cannot erase another")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/wall_markings_reference.json"))
	var exercised: int = 0
	for row: Dictionary in fixture.cases:
		if not row.id.begins_with("fresh_") and not row.id.begins_with("poster_wall_"): continue
		var state: Dictionary = row.steps[0].expected
		_check(first.sync(_snapshot(state.graffiti,state.posters),surfaces),"actual source generated layout: "+row.id)
		await process_frame
		var projected: Dictionary = first.inspect()
		_check(projected.rejected.is_empty() and projected.requested == state.graffiti.size()+state.posters.size() and projected.placed == projected.requested,"no source generated record silently dropped: "+row.id)
		_geometry(first,surfaces,row.id); exercised += 1
	_check(exercised >= 10,"fresh min/max/random streams and all poster wall choices exercised")
	var longest: Array[Dictionary] = _longest_fronts(surfaces)
	_check(longest.size() == surfaces.size() and first.sync(_snapshot(longest,[]),surfaces),"longest eligible source sentence exercises every building front")
	await process_frame
	_check(first.inspect().placed == longest.size() and first.inspect().rejected.is_empty(),"all longest canonical front tags fit between actual piers: "+str(first.inspect().rejected))
	_geometry(first,surfaces,"longest front counterexamples")
	# A long rotated rectangle reaches its widest horizontal envelope between
	# the source's two rotation endpoints, not necessarily at either endpoint.
	var peak: Dictionary = longest[16].duplicate(true); peak.rot = 0.043
	var peak_snapshot: Dictionary = _snapshot([peak],[]); var peak_before: Dictionary = peak_snapshot.duplicate(true)
	_check(first.sync(peak_snapshot,surfaces),"interior-angle long-line pier regression projects")
	await process_frame
	var peak_info: Dictionary = first.inspect()
	_check(peak_info.requested == 1 and peak_info.placed == 1 and peak_info.rejected.is_empty() and peak_snapshot == peak_before,"interior-angle long line remains whole and unchanged")
	if peak_info.placed == 1: _check(peak_info.records[0].scale < 0.30,"long sentence uses a real smaller fit between piers")
	_geometry(first,surfaces,"interior-angle long-line counterexample")
	var invalid: Array = [null,{}, {"x":NAN,"y":4,"text":"broken"}, {"x":0,"y":0,"text":"unknown wall","wallKind":"bottom","wallX":0,"wallW":1,"textW":1,"rot":0,"sz":9,"col":"#a08070"}]
	_check(first.sync(_snapshot(invalid,[]),surfaces) and first.inspect().rejected.size() == 4 and first.inspect().placed == 0,"unplaceable legacy records are explicitly reported by index")
	var absent: Array = surfaces.duplicate(true)
	for entry: Dictionary in absent:
		for face: Dictionary in entry.faces.values(): face.panels.clear()
	first.sync(saved,absent); _check(first.inspect().rejected.size() == 23 and first.inspect().placed == 0,"no clear wall reports every record without source reduction")
	for malformed: Array in [[],[{}],[{"source":{},"faces":{}}]]:
		first.sync(saved,surfaces); _check(not first.sync(saved,malformed) and first.get_child_count() == 0,"invalid surface contract clears stale presentation")
	var bad: Array = surfaces.duplicate(true); var bad_transform: Transform3D = bad[0].faces.bottom.transform
	bad_transform.origin.x = INF; bad[0].faces.bottom.transform = bad_transform
	_check(not first.sync(saved,bad),"nonfinite face transform rejected before mesh construction")
	_check(first.inspect().queries == 0 and first.inspect().dynamic_shadows == 0,"presentation never runs physical queries or shadow work")
	_check(Content.load_content().initial.state.graffiti == saved.graffiti and Content.load_content().initial.state.posters == saved.posters,"immutable content remains unchanged after all redraws")
	first.free(); second.free(); world.free(); await process_frame
	if failures.is_empty(): print("3D WALL MARKING VIEW GATE: PASS (%d checks)"%checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D WALL MARKING VIEW GATE: FAIL (%d failures/%d checks)"%[failures.size(),checks]); quit(1)
