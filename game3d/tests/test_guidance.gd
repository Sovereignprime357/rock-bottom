extends SceneTree
const State = preload("res://scripts/game_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Office = preload("res://scripts/office_campaign.gd")
const Kingdom = preload("res://scripts/kingdom_campaign.gd")
const Guidance = preload("res://scripts/guidance_view.gd")
const HUD = preload("res://scripts/full_hud.gd")
var checks: int = 0
var failures: Array[String] = []
var fixture: Dictionary = {}
var completed: int = 0
var groups: int = 0

class HUDRuntime:
	extends RefCounted
	var state: RefCounted
	var progression: RefCounted
	var memory: RefCounted
	var p: Dictionary:
		get: return state.p
	var s: Dictionary:
		get: return state.s
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a)-float(b)) <= 0.00001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index: int in range(a.size()):
			if not _same(a[index],b[index]): return false
		return true
	return a == b
func _merge(base: Dictionary,patch: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: String in patch:
		if patch[key] is Dictionary and result.get(key) is Dictionary: result[key] = _merge(result[key],patch[key])
		else: result[key] = patch[key].duplicate(true) if patch[key] is Dictionary or patch[key] is Array else patch[key]
	return result
func _bundle() -> Dictionary:
	var state := State.new(); var progression := Progression.new(state); var memory := Memory.new(state)
	var campaign := Campaign.new(state); var office := Office.new(state,null,campaign,progression,null)
	var kingdom := Kingdom.new(state,null,campaign,office,null,memory,null,null)
	var view := Guidance.new(state,progression,memory,office,kingdom,campaign)
	return {"state":state,"progression":progression,"memory":memory,"campaign":campaign,"office":office,"kingdom":kingdom,"view":view}
func _setup(bundle: Dictionary,patch: Dictionary) -> void:
	var values: Dictionary = _merge(fixture.baseline,patch); var state: RefCounted = bundle.state
	for key: String in values.p: state.p[key] = values.p[key]
	for key: String in values.s: state.s[key] = values.s[key]
	state.npcs.assign(values.npcs); state.cash_piles.assign(values.cash); state.events.clear()
func _whole(state: RefCounted) -> Dictionary:
	return {"p":state.p.duplicate(true),"s":state.s.duplicate(true),"actors":state.npcs.duplicate(true),"cash":state.cash_piles.duplicate(true),"events":state.events.duplicate(true),"rng":state.rng_seed}
func _plain(text: String) -> String:
	var whitespace := RegEx.new(); whitespace.compile("\\s+")
	return whitespace.sub(text," ",true).strip_edges()
func _expected_map(row: Dictionary) -> Array:
	var expected: Array = fixture.mapDynamic.duplicate(true); expected.resize(int(row.mapLength))
	for change: Dictionary in row.mapChanges: expected[int(change.index)] = change.value
	return expected
func _source() -> void:
	_check(fixture.counts.cases == 165 and fixture.cases.size() == 165,"all165 independent unchanged-source views")
	_check(fixture.counts.quests == 24 and fixture.counts.hustles == 14,"full24quest/14hustle source inventory")
	_check(fixture.originalDefect == "ReferenceError: npcs is not defined","original known-vendor source defect remains characterized separately")
	for row: Dictionary in fixture.cases:
		var bundle: Dictionary = _bundle(); _setup(bundle,row.before)
		var before: Dictionary = _whole(bundle.state); var view: RefCounted = bundle.view
		_check(view.ready(),row.id+" real read authorities exist")
		var objective: Dictionary = view.primary_objective()
		_check(_same(objective,row.objective),row.id+" source objective got "+str(objective)+" expected "+str(row.objective))
		var journal: String = _plain(view.journal_text()); journal = journal.substr(journal.find("NOW "))
		_check(journal == row.journal,row.id+" full normalized source journal\nACTUAL "+journal+"\nEXPECTED "+str(row.journal))
		_check(_same(view.map_static(),fixture.mapStatic),row.id+" source cached zones/roads/facades/rail draw order")
		var map: Dictionary = view.map_dynamic(); var expected: Array = _expected_map(row)
		_check(_same(map.commands,expected),row.id+" source claim/clan/office/actor/objective/player draw calls")
		_check(_same(_whole(bundle.state),before) and row.randomCalls == 0,row.id+" allviews pure p/s/actors/cash/events/RNG")
		completed += 1
	groups += 1
func _directions() -> void:
	_check(fixture.directions.size() == 58,"all58 actual source direction boundary cases")
	for row: Dictionary in fixture.directions:
		_check(Guidance.objective_direction(row.dx,row.dy) == row.stableExpected,"source octant or approved exact-half normalization "+str(row))
		if not row.ambiguous: _check(row.stableExpected == row.expected,"away from libm bisector exact unchanged V8 result")
	_check(Guidance.source_round(-0.5) == 0 and Guidance.source_round(-1.5) == -1 and Guidance.source_round(0.5) == 1,"JS negative half ties round toward positive infinity")
	var bundle: Dictionary = _bundle(); _setup(bundle,{})
	var center: Vector2 = bundle.state.player_center()
	# The source HUD's circular HERE test is distinct from the square octant helper.
	bundle.state.cash_piles.assign([{"intro":true,"x":center.x+23,"y":center.y+23,"collected":false}])
	var current: Dictionary = bundle.view.objective_view(0)
	_check(not current.here and current.direction == "HERE" and current.paces == 4,"source circular HUD vs square direction HERE distinction")
	for yaw: float in [0.0,PI/2.0,PI,-PI/2.0,TAU*8.0,NAN,INF]:
		current = bundle.view.objective_view(yaw)
		_check(is_finite(current.bearing) and current.bearing >= -PI and current.bearing <= PI,"finite wrapped camera-relative bearing")
	bundle.state.cash_piles.assign([{"intro":true,"x":center.x,"y":center.y-100,"collected":false}])
	_check(is_zero_approx(bundle.view.objective_view(0).bearing),"north target ahead at zero Godot yaw")
	_check(absf(bundle.view.objective_view(PI/2.0).bearing-PI/2.0) < 0.000001,"turn left places north target to right")
	for distance: float in [27.999,28.0,28.001]:
		bundle.state.cash_piles.assign([{"intro":true,"x":center.x+distance,"y":center.y,"collected":false}])
		current = bundle.view.objective_view()
		_check(current.here == (distance < 28.0),"strict28px HERE boundary "+str(distance))
	groups += 1
func _properties() -> void:
	var bundle: Dictionary = _bundle(); _setup(bundle,{})
	var before: Dictionary = _whole(bundle.state)
	var journal: Dictionary = bundle.view.journal(); journal.sections[1].rows[0].title = "changed"
	var objective: Dictionary = bundle.view.primary_objective(); objective.text = "changed"
	var map: Dictionary = bundle.view.map_dynamic(); map.commands[0].color = "#fff"
	var static_map: Array = bundle.view.map_static(); static_map[0].values[0] = 99999
	_check(_same(_whole(bundle.state),before),"detached returned views never mutate model")
	_check(bundle.view.journal().sections[1].rows[0].title != "changed" and bundle.view.primary_objective().text != "changed","mutating view copies does not poison later views")
	_check(bundle.view.map_static()[0].values[0] == 0,"mutating returned static map does not poison cache")
	var original_count: int = bundle.view.map_dynamic().commands.size()
	bundle.state.npcs.append({"id":"qa_departed","x":100,"y":200,"departed":true})
	_check(bundle.view.map_dynamic().commands.size() == original_count,"approved departed-exit adaptation omits marker")
	bundle.state.npcs.append({"id":"qa_night_hidden","x":100,"y":200,"nightOnly":true})
	_check(bundle.view.map_dynamic().commands.size() == original_count+1,"source minimap retains living night-hidden actor information")
	# Pure presenter follows replacement state without retaining mutable p/s epochs.
	bundle.state.fresh(); bundle.state.s.counters.introCashEarned = 7
	_check(bundle.view.primary_objective().text.ends_with("$7/10"),"fresh identity reads current authority")
	bundle.state.p = bundle.state.p.duplicate(true); bundle.state.s = bundle.state.s.duplicate(true); bundle.state.s.counters.introCashEarned = 8
	_check(bundle.view.primary_objective().text.ends_with("$8/10"),"restore identity reads current authority")
	var weak: WeakRef = weakref(bundle.kingdom); bundle.kingdom = null
	_check(weak.get_ref() == null and not bundle.view.ready(),"presenter holds owners weakly")
	_check(bundle.view.primary_objective().is_empty() and bundle.view.journal().is_empty() and bundle.view.journal_text().is_empty() and bundle.view.map_dynamic().is_empty(),"missing authority fails closed without gameplay fallback")
	groups += 1
func _hud() -> void:
	var original_size: Vector2i = root.size; var original_scale: Vector2i = root.content_scale_size
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1280,720)
	var bundle: Dictionary = _bundle(); _setup(bundle,{})
	var runtime := HUDRuntime.new(); runtime.state = bundle.state; runtime.progression = bundle.progression; runtime.memory = bundle.memory
	var hud := HUD.new(); root.add_child(hud); hud.set_process(false)
	await process_frame
	var original_receipt := Vector4(hud.receipt.offset_left,hud.receipt.offset_top,hud.receipt.offset_right,hud.receipt.offset_bottom)
	hud.bind_guidance(bundle.view); hud.update_runtime(runtime)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions; await process_frame; await process_frame
		var viewport := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		var map_rect: Rect2 = hud.guidance_map.get_global_rect(); var receipt_rect: Rect2 = hud.receipt.get_global_rect()
		_check(viewport.size.is_equal_approx(Vector2(dimensions)),"actual resized viewport "+str(dimensions))
		_check(hud.guidance_map.visible and viewport.encloses(map_rect) and map_rect.size.is_equal_approx(Vector2(240,192)),"minimap global rectangle genuinely visible at "+str(dimensions))
		_check(absf(map_rect.position.x-(viewport.size.x-260.0)) < 0.01 and absf(map_rect.position.y-(viewport.size.y-246.0)) < 0.01,"minimap uses bottom-right offsets, not negative absolute position")
		_check(viewport.encloses(receipt_rect) and receipt_rect.end.x <= map_rect.position.x-19.0,"shifted receipt remains on screen beside minimap")
	var before: Dictionary = _whole(bundle.state); var count: int = hud.guidance_refresh_count
	hud._process(0.119); _check(hud.guidance_refresh_count == count,"HUD120ms presentation cadence waits")
	hud._process(0.0011); _check(hud.guidance_refresh_count == count+1,"HUD120ms refresh reads actual authority")
	bundle.state.p.rockedT = 18000.0; hud.update_runtime(runtime)
	_check(hud.objective.text.begins_with("BAD IDEA") and hud._loop_status.text.contains("ROCKED UP"),"objective stays visible beside high status")
	bundle.state.p.rockedT = 0.0; bundle.state.p.crashT = 8000.0; hud.update_runtime(runtime)
	_check(hud.objective.text.begins_with("BAD IDEA") and hud._loop_status.text.contains("THE CRASH"),"objective stays visible beside crash status")
	bundle.state.p.crashT = 0.0; bundle.state.s.mode = "dialogue"; hud.update_runtime(runtime); count = hud.guidance_refresh_count
	hud._process(3.0); _check(hud.guidance_refresh_count == count and not hud.guidance_map.visible,"modal hides map and pauses presentation refresh")
	bundle.state.s.mode = "playing"; hud.update_runtime(runtime); hud.set_view_heading(PI/2.0); hud._process(0.12)
	_check(hud.guidance_map.visible and hud.guidance_map.heading == PI/2.0,"actual camera heading arrives without rotating source map")
	hud.set_view_heading(NAN); _check(is_finite(hud.guidance_map.heading),"nonfinite camera heading refused")
	bundle.state.s.mode = "dialogue"; hud.update_runtime(runtime); hud.bind_guidance(null)
	_check(not hud.objective.visible and not hud.guidance_map.visible,"explicit unbind while modal does not reveal gameplay overlay")
	_check(Vector4(hud.receipt.offset_left,hud.receipt.offset_top,hud.receipt.offset_right,hud.receipt.offset_bottom) == original_receipt,"explicit unbind restores original receipt offsets")
	bundle.state.s.mode = "playing"; hud.update_runtime(runtime)
	_check(hud.objective.visible and hud.objective.text.begins_with("BAD IDEA"),"bind→modal→unbind→resume restores visible fallback objective")
	_check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(hud.receipt.get_global_rect()),"unbound receipt remains physically inside viewport")
	_check(_same(_whole(bundle.state),before),"HUD refresh/status changes have no model/RNG/event writes")
	hud.queue_free(); await process_frame
	root.size = original_size; root.content_scale_size = original_scale
	groups += 1
func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/guidance_reference.json"))
	if not parsed is Dictionary: push_error("GUIDANCE fixture invalid"); quit(1); return
	fixture = parsed
	_source(); _directions(); _properties(); await _hud()
	_check(completed == 165 and groups == 4,"all165 oracle views and four test groups completed; no skipped function abort")
	if failures.is_empty(): print("3D GUIDANCE: PASS (%d checks / 165 source views / 58 directions)" % checks); quit(0)
	else:
		for failure: String in failures: print("FAIL: "+failure)
		print("3D GUIDANCE: FAIL (%d/%d)" % [failures.size(),checks]); quit(1)
