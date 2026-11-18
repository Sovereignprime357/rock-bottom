extends SceneTree
const Runtime = preload("res://scripts/full_runtime.gd")
const Hud = preload("res://scripts/full_hud.gd")
class Spatial extends RefCounted:
	func can_reach_target(_id: String) -> bool: return true
	func can_use_zone(_id: String) -> bool: return true
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _run() -> void:
	root.size = Vector2i(1280,720)
	var spatial := Spatial.new()
	var runtime: RefCounted = Runtime.new(spatial)
	runtime.fresh()
	var hud: CanvasLayer = Hud.new(); root.add_child(hud)
	await process_frame
	var before: String = JSON.stringify(runtime.snapshot())
	hud.update_runtime(runtime)
	_check(hud.status.text.contains("DAY 1") and hud.pocket.text.contains("rocks 0"),"full source HUD reads fresh resources")
	var pocket_rect: Rect2 = hud.pocket.get_global_rect()
	_check(pocket_rect.position.x >= 720 and pocket_rect.end.x <= 1280 and pocket_rect.position.y >= 0,"actual resource panel stays on right side of viewport")
	var copy: String = hud.inventory_copy(runtime)
	_check(copy.contains("equipment") and copy.contains("lifetime") and copy.contains("cursed accolades"),"full inventory exposes actual source sections")
	_check(not copy.contains("eat the food"),"full inventory adds no invented consumption action")
	_check(JSON.stringify(runtime.snapshot()) == before,"HUD and ledger do not mutate authoritative state")
	runtime.p.rockedT = 18000.0
	hud.update_runtime(runtime)
	_check(hud.objective.text.contains("18.0s"),"source milliseconds displayed as high seconds")
	runtime.p.rockedT = 0.0; runtime.p.crashT = 8000.0
	hud.update_runtime(runtime)
	_check(hud.objective.text.contains("8.0s"),"source crash display")
	var options: Array[Dictionary] = []
	for index: int in range(25): options.append({"label":"entry %d" % index,"action":func(): pass})
	options.append({"label":"leave.","action":hud.close_menu})
	hud.menu("YOUR POCKETS",copy,options)
	await process_frame; await process_frame
	_check(hud.modal.visible and not hud.crosshair.visible,"modal opens without exposing gameplay crosshair")
	_check(hud.menu_scroll.get_v_scroll_bar().max_value > hud.menu_scroll.size.y,"long source menus genuinely scroll")
	_check(hud.modal.get_global_rect().end.y <= 720 and hud.modal.get_global_rect().position.y >= 0,"long menu remains inside720p viewport")
	hud.menu_scroll.scroll_vertical = int(hud.menu_scroll.get_v_scroll_bar().max_value)
	await process_frame
	var leave: Button = hud.menu_box.get_child(hud.menu_box.get_child_count()-1)
	_check(leave.text == "leave." and leave.get_global_rect().intersects(hud.menu_scroll.get_global_rect()),"last Leave option physically reachable afterscroll")
	leave.pressed.emit()
	_check(not hud.modal.visible and hud.crosshair.visible,"Leave closes menu once")
	hud.menu("STILL HERE","the block continues.",[{"label":"continue.","action":hud.close_menu}])
	await process_frame
	_check(hud.menu_scroll.scroll_vertical == 0,"new menu resets old scroll position")
	var selections: Array[int] = [0]
	hud.menu("CHOICES","the list.",[{"label":"unavailable.","disabled":true,"action":func(): selections[0] += 10},{"label":"available.","action":func(): selections[0] += 1}])
	await process_frame
	_check(not hud.activate_choice(0) and selections[0] == 0,"number shortcuts cannot activate disabled source choices")
	_check(hud.activate_choice(1) and selections[0] == 1,"number shortcut invokes matching actual button once")
	_check(not hud.activate_choice(8) and selections[0] == 1,"missing ninth choice is inert")
	hud.close_menu()
	_check(not hud.activate_choice(1) and selections[0] == 1,"closed modal shortcuts are inert")
	runtime.communications.post("the phone has a post.","@phone_guy")
	runtime.communications.show_feed()
	hud.update_communications(runtime.communications.snapshot()); hud.update_runtime(runtime)
	await process_frame; await process_frame
	_check(hud.feed_panel.visible and hud.feed_copy.text.contains("the phone has a post."),"actual feed snapshot renders during play")
	var feed_rect: Rect2 = hud.feed_panel.get_global_rect()
	_check(feed_rect.position.x >= 900 and feed_rect.end.x <= 1280 and feed_rect.end.y < 520,"phone panel fits desktop viewport")
	runtime.set_mode("dialogue"); hud.update_runtime(runtime)
	_check(not hud.feed_panel.visible,"dialogue hides feed without resetting visibility")
	runtime.close_dialogue(); hud.update_runtime(runtime)
	_check(hud.feed_panel.visible,"closing dialogue restores requested phone view")
	hud.free(); runtime = null; spatial = null
	await process_frame
	if failures.is_empty():
		print("3D FULL HUD GATE: PASS (%d checks; pure model view, full ledger, status units and reachable scrolling menus)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL HUD GATE: FAIL (%d / %d checks)" % [failures.size(),checks]); quit(1)
