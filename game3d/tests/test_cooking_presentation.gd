extends SceneTree

const Presentation = preload("res://scripts/cooking_presentation.gd")
const Cooking = preload("res://scripts/cooking_system.gd")
const State = preload("res://scripts/game_state.gd")
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []

class Spatial extends RefCounted:
	func can_use_zone(id: String) -> bool: return id == "block"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	var view := Presentation.new()
	root.add_child(view)
	await _frames(3)
	_real_snapshots(view)
	_outcomes_and_bounds(view)
	_smoke_and_resolution(view)
	_passive(view)
	await _layout_checks(view)
	view.free()
	_check(groups == 5,"all five view groups completed without script abort")
	if failures.is_empty():
		print("3D COOKING PRESENTATION GATE: PASS (%d checks; pure supplied-state view, source labels, finite bar, smoke, narrow layout; root input/render acceptance pending)" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D COOKING PRESENTATION GATE: FAIL (%d failures / %d checks)" % [failures.size(),checks])
		quit(1)

func _check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _frames(count: int) -> void:
	for index: int in range(count): await process_frame

func _fixture(changes: Dictionary = {}) -> Dictionary:
	var heat := {"active":true,"mode":"slow","n":1,"phase":"fill","progress":0.55,"sweetCenter":0.55,"sweetHalf":0.11,"burnZone":0.08,"lockedAt":null,"outcome":null,"holdT":600.0}
	heat.merge(changes,true)
	return heat

func _real_snapshots(view: Presentation) -> void:
	var labels := {"slow":"low and slow","fast":"fast cook","shakes":"shaky special","all":"cook all","propane":"propane"}
	for mode: String in labels:
		var game := State.new()
		var spatial := Spatial.new()
		var cooking := Cooking.new(game,spatial)
		game.s.mode = "playing"; game.p.supplies = 5; game.p.dirtySupplies = 2
		game.p.shakes = 65; game.p.rockedT = 18000.0; game.p.crashT = 0.0
		game.p.equip.tool = "propane_torch"
		var menu: Dictionary = cooking.open_menu()
		var begun: Dictionary = cooking.select(menu.get("token",""),mode)
		_check(begun.get("started",false),mode+" uses an actual Cooking snapshot")
		game.s.smokeT = 1250.0
		var heat: Dictionary = cooking.snapshot()
		var before := {"player":game.p.duplicate(true),"state":game.s.duplicate(true),"events":game.events.duplicate(true),"rng":game.rng_seed}
		for index: int in range(90): view.update(heat,game.p,game.s.smokeT,100.0 if index == 0 else 1.0/60.0)
		var n: int = heat.n
		var dirty := mini(n,2)
		_check(view.title.text == "the heat." and view.subtitle.text == "%s — %d packet%s — clean × %d + dirty × %d" % [labels[mode],n,"" if n == 1 else "s",n-dirty,dirty],mode+" exact title/mode/plural/dirty subtitle")
		_check(view.help.text == "space / tap — lock the heat. esc — walk away." and not view.outcome.visible,mode+" exact fill instructions with no invented outcome")
		_check(game.p == before.player and game.s == before.state and game.events == before.events and game.rng_seed == before.rng,mode+" rendering does not advance clocks, spend, settle, emit or draw RNG")
		_check(cooking.snapshot() == heat and view.bar.display.progress == heat.progress,mode+" repeated view updates never move or lock the supplied needle")
		var retained: Dictionary = view.bar.display.duplicate(true)
		var retained_text: String = view.subtitle.text
		heat.progress = 0.99; heat.sweetCenter = 0.0; heat.mode = "unknown"
		_check(view.bar.display == retained and view.subtitle.text == retained_text,mode+" input dictionary is not retained as mutable view state")
	var idle := _fixture({"phase":"idle","progress":1.0})
	view.update(idle,{},0,0)
	_check(view.help.text == "you're letting it burn. tap to save it.","idle uses the exact source warning")
	groups += 1

func _outcomes_and_bounds(view: Presentation) -> void:
	var labels := {"perfect":"PERFECT.","ok":"OK.","bad":"BAD COOK.","burn":"BURNT.","undercook":"NEVER SET.","soaprock":"SOAP."}
	for result: String in labels:
		# The locked position deliberately remains in the sweet region. The view
		# must trust the supplied outcome even when those fields disagree.
		view.update(_fixture({"phase":"hold","outcome":result,"lockedAt":0.55}),{},0,0)
		var expected := Color("e8c040") if result == "perfect" else (Color("8a3a3a") if result == "burn" else (Color("d488d4") if result == "soaprock" else Color("d4c896")))
		_check(view.outcome.visible and view.outcome.text == labels[result] and view.help.text == "· "+String(labels[result]).to_lower()+" ·",result+" displays the supplied source outcome without recomputation")
		_check(view.outcome.get_theme_color("font_color") == expected,result+" retains source outcome color")
	for endpoint: float in [0.0,1.0]:
		view.update(_fixture({"phase":"hold","outcome":"ok","lockedAt":endpoint}),{},0,0)
		var geometry: Dictionary = view.bar.geometry()
		_check(geometry.has_lock and is_equal_approx(geometry.locked_x,geometry.bar.position.x if endpoint == 0.0 else geometry.bar.end.x),"locked endpoint %s has its own marker" % endpoint)
	for invalid: Variant in [null,NAN,INF,"0",false,{}]:
		view.update(_fixture({"lockedAt":invalid}),{},0,NAN)
		_check(not view.bar.geometry().has_lock,"malformed/null lockedAt cannot invent a locked marker: "+str(invalid))
	var cases: Array[Dictionary] = [
		{"progress":NAN,"sweetCenter":INF,"sweetHalf":-INF,"burnZone":"hot","n":"one"},
		{"progress":-20.0,"sweetCenter":-5.0,"sweetHalf":4.0,"burnZone":4.0,"n":-10},
		{"progress":20.0,"sweetCenter":5.0,"sweetHalf":-4.0,"burnZone":-4.0,"n":1000000000000},
		{"progress":{},"sweetCenter":null,"sweetHalf":true,"burnZone":[],"n":NAN}]
	for fields: Dictionary in cases:
		view.update(_fixture(fields),{"dirtySupplies":INF},0,-100)
		var geometry: Dictionary = view.bar.geometry()
		var finite: bool = true
		for key: String in ["bar","sweet","burn"]:
			var rect: Rect2 = geometry[key]
			finite = finite and rect.position.is_finite() and rect.size.is_finite() and rect.size.x >= 0 and rect.size.y >= 0
			finite = finite and rect.position.x >= geometry.bar.position.x and rect.end.x <= geometry.bar.end.x
		for key: String in ["center_x","needle_x","locked_x"]:
			finite = finite and is_finite(geometry[key]) and geometry[key] >= geometry.bar.position.x and geometry[key] <= geometry.bar.end.x
		_check(finite,"malformed/extreme display numbers retain finite bounded drawing geometry")
		_check(not view.subtitle.text.contains("nan") and not view.subtitle.text.contains("inf"),"malformed counts never leak nonfinite numeric text")
	for fields: Dictionary in [{"active":1},{"mode":"unknown"},{"phase":"unknown"},{"mode":{}},{"phase":false}]:
		view.update(_fixture(fields),{},0,0)
		_check(not view.panel.visible and not view.dim.visible,"invalid active/mode/phase suppresses heat chrome safely")
	groups += 1

func _smoke_and_resolution(view: Presentation) -> void:
	for smoke_ms: float in [2000.0,1000.0,1.0,4000.0]:
		for index: int in range(120): view.update({}, {},smoke_ms,1.0/60.0)
		_check(view.smoke.visible and is_equal_approx(view.smoke.opacity,clampf(smoke_ms/2000.0,0,1)),"smoke lifetime %s remains entirely supplied after repeated renders" % smoke_ms)
		_check(not view.panel.visible and not view.dim.visible and view.smoke_caption.text == "the smoke is in the floor.","smoke survives an empty heat snapshot with source caption")
	for smoke_ms: float in [0.0,-1.0,NAN,INF]:
		view.update({}, {},smoke_ms,0)
		_check(not view.smoke.visible and view.smoke.opacity == 0,"zero or malformed smoke lifetime hides haze immediately")
	view.update(_fixture(),{},1000,0)
	_check(view.root_control.get_children().find(view.smoke) < view.root_control.get_children().find(view.dim),"source smoke draws below heat dim and panel")
	view.update(_fixture({"phase":"resolve","outcome":"perfect","lockedAt":0.55}),{},0,0)
	_check(view.help.text == "the batch is settling." and view.outcome.visible and view.outcome.text == "PERFECT." and not view.resolution.visible,"resolving retains accepted result and shows no invented progress or stale input instruction")
	view.update(_fixture({"phase":"resolve","outcome":"ok","resolution":{"processed":2048,"total":5000}}),{},0,0)
	_check(view.resolution.visible and view.resolution.text == "2048 / 5000 packets","optional resolving counts report actual supplied chunk work")
	for progress: Variant in [{},{"processed":1.5,"total":5},{"processed":6,"total":5},{"processed":-1,"total":5},{"processed":0,"total":0},{"processed":NAN,"total":5},{"processed":1,"total":INF},{"processed":"1","total":5},false]:
		view.update(_fixture({"phase":"resolve","resolution":progress}),{},0,0)
		_check(not view.resolution.visible and view.resolution.text.is_empty(),"malformed or absent progress cannot invent a percentage/count")
	groups += 1

func _passive(node: Node) -> void:
	_check(not node.is_processing() and not node.is_processing_input() and not node.is_processing_unhandled_input(),"presentation layer has no autonomous clock or input handler")
	var controls: Array[Node] = node.find_children("*","Control",true,false)
	var all_passive: bool = not controls.is_empty()
	for control: Control in controls:
		all_passive = all_passive and control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE and not control is BaseButton
	_check(all_passive,"every control passes pointer input and refuses keyboard focus; no duplicate buttons")
	groups += 1

func _layout_checks(view: Presentation) -> void:
	view.update(_fixture({"phase":"hold","outcome":"burn","lockedAt":0.96}),{},0,0)
	await _frames(4)
	var area: Rect2 = root.get_visible_rect()
	var rect: Rect2 = view.panel.get_global_rect()
	_check(area.encloses(rect) and view.dim.get_global_rect() == area and view.smoke.get_global_rect() == area,"desktop overlay covers the actual logical viewport and contains its heat panel")
	_check(not rect.intersects(Rect2(0,0,1280,100)) and not rect.intersects(Rect2(0,596,280,124)),"desktop heat panel leaves top resources and bottom meter plate unobstructed")
	_check(rect.encloses(view.bar.get_global_rect()) and rect.encloses(view.help.get_global_rect()) and rect.encloses(view.outcome.get_global_rect()),"desktop bar/help/result remain within panel")
	var small := SubViewport.new()
	small.size = Vector2i(390,700)
	small.disable_3d = true
	root.add_child(small)
	var narrow := Presentation.new()
	small.add_child(narrow)
	narrow.update(_fixture({"mode":"all","n":1000000000,"phase":"resolve","outcome":"soaprock","resolution":{"processed":123456789,"total":1000000000}}),{"dirtySupplies":500000000},1000,0)
	await _frames(6)
	_check(small.get_visible_rect().encloses(narrow.panel.get_global_rect()) and narrow.dim.get_global_rect() == small.get_visible_rect(),"narrow logical viewport contains entire panel and full dim without clipping")
	for child: Control in [narrow.title,narrow.subtitle,narrow.bar,narrow.help,narrow.outcome,narrow.resolution]:
		_check(narrow.panel.get_global_rect().encloses(child.get_global_rect()),"narrow panel contains wrapped "+child.get_class()+" content")
	_check(narrow.subtitle.get_line_count() >= 2 and narrow.subtitle.get_visible_line_count() == narrow.subtitle.get_line_count(),"long narrow subtitle wraps into visible lines")
	_check(is_same(view.bar.texture,narrow.bar.texture),"view instances share the immutable authored heat texture")
	small.size = Vector2i(520,600)
	await _frames(6)
	_check(small.get_visible_rect().encloses(narrow.panel.get_global_rect()) and narrow.smoke.get_global_rect() == small.get_visible_rect(),"resized independent viewport retains panel and full smoke coverage")
	small.size = Vector2i(160,180)
	await _frames(6)
	_check(small.get_visible_rect().encloses(narrow.panel.get_global_rect()) and narrow.panel.scale.x < 1.0,"tiny host viewport scales the complete panel rather than clipping its contents")
	_check(narrow.panel.get_global_rect().encloses(narrow.outcome.get_global_rect()) and narrow.panel.get_global_rect().encloses(narrow.resolution.get_global_rect()),"tiny host viewport retains locked outcome and actual resolving counts")
	small.free()
	groups += 1
