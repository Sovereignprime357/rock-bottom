extends SceneTree
## Real production scene, authored world/roster and physics; no fake reach/spawn facade.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
const CENTER := Vector2(3772,714)
class MemoryStore:
	extends "res://scripts/save_store.gd"
	var writes: Array[Dictionary] = []
	func write_save(data: Dictionary) -> bool:
		writes.append(data.duplicate(true)); return true
	func read_save() -> Dictionary: return {}
var game: Node3D
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _place(center: Vector2,aim: bool = true) -> void:
	game.runtime.p.x = float(center.x)-float(game.runtime.p.w)*0.5
	game.runtime.p.y = float(center.y)-float(game.runtime.p.h)*0.5
	game._sync_player()
	if aim: game.camera.look_at(game.world.service_points.oldschool.target)
func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event)
func _buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in game.hud.menu_box.get_children():
		if child is Button: result.append(child)
	return result
func _actor() -> Dictionary:
	for actor: Dictionary in game.runtime.state.npcs:
		if actor.id == "os_brutus": return actor
	return {}
func _fingerprint() -> Dictionary:
	return {"save":game.runtime.snapshot(),"actors":game.runtime.state.npcs.duplicate(true),"rng":game.runtime.state.rng_seed,"mode":game.runtime.s.mode}
func _standing() -> bool:
	var body: Dictionary = game.runtime.combat._geometry(game.runtime.p)
	return game.physics._clear(body,Vector2(body.x,body.y),false)
func _open() -> Dictionary:
	game.runtime.close_dialogue(); _place(CENTER+Vector2(0,30)); game.runtime.p.rank = 3
	var page: Dictionary = game.runtime.open_old_school()
	_check(page.get("ok",false) and page.has("token"),"real runtime opens Old School capability")
	return page
func _range_and_los() -> void:
	var service: Dictionary = game.world.service_points.oldschool
	_check(service.source_point == CENTER and is_equal_approx(service.reach,1.76),"exact source center and unchanged44px service")
	_check(service.approach.is_finite(),"authored door has a physical approach")
	_place(Content.to_source(service.approach))
	_check(_standing() and game.physics.can_reach_target("oldschool"),"canonical approach fits real capsule and eye ray")
	for offset: float in [44.0,44.01,43.99]:
		_place(CENTER+Vector2(0,offset)); game.runtime.p.rank = 3
		_check(_standing(),"strict-radius witness is physically clear:%s" % offset)
		var expected: bool = offset < 44.0
		_check(game.physics.can_reach_target("oldschool") == expected,"actual physics strict44:%s" % offset)
		var result: Dictionary = game.runtime.open_old_school()
		_check(result.get("ok",false) == expected,"owner strict44 agrees:%s" % offset)
		game.runtime.close_dialogue()
	# Approach through actual swept movement with the complete living roster retained.
	_place(CENTER+Vector2(0,52))
	for step: int in range(18):
		var body: Dictionary = game.runtime.combat._geometry(game.runtime.p)
		var moved: Dictionary = game.physics.move_body(body,Vector2(body.x,body.y)+Vector2(0,-0.5))
		game.runtime.p.x = moved.position.x; game.runtime.p.y = moved.position.y
	game._sync_player(); game.camera.look_at(service.target)
	_check(game.runtime.state.player_center().distance_to(CENTER) < 44 and _standing(),"real movement reaches door without collider or roster bypass")
	_check(game.resolve_interaction().get("kind") == "oldschool","actual aimed controller resolves reached door")
	var eye: Vector3 = game.camera.global_position
	var blocker := StaticBody3D.new(); blocker.collision_layer = 1; blocker.collision_mask = 0
	blocker.set_meta("source_owner","old_school_test_unrelated")
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(0.12,0.4,0.12)
	collision.shape = shape; blocker.add_child(collision); game.world.add_child(blocker)
	blocker.global_position = eye.lerp(service.target,0.5)
	await physics_frame; await physics_frame; game.physics.invalidate_placement_cache()
	_check(_standing(),"LOS blocker does not embed the player")
	var before: Dictionary = _fingerprint()
	_check(not game.physics.can_reach_target("oldschool") and not game.runtime.open_old_school().get("ok",false),"unrelated actual collider blocks door")
	_check(game.resolve_interaction().get("kind") != "oldschool" and _fingerprint() == before,"blocked entry has no state/RNG/actor effects")
	blocker.free(); await physics_frame; game.physics.invalidate_placement_cache()
	_check(game.physics.can_reach_target("oldschool"),"removing live blocker restores access")
	groups += 1
func _controls_and_spawn() -> void:
	_place(CENTER+Vector2(0,30)); game.runtime.p.rank = 2
	_key(KEY_E)
	_check(game.runtime.s.mode == "dialogue" and _buttons().size() == 1,"rank2 actualE renders only source leave")
	_check(game.runtime.old_school._locked and game.hud.modal.visible,"rank gate is the real source owner")
	_key(KEY_1)
	_check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"numbered locked leave resumes")
	game.runtime.p.rank = 3; game.runtime.p.stunT = 1
	_check(game.resolve_interaction().is_empty(),"Scene stun gate rejects sourceE before entry")
	game.runtime.p.stunT = 0
	game.runtime.s.bossActive = true; game.runtime.s.bossKind = "tony"
	_check(game.resolve_interaction().get("kind") == "oldschool","ordinary boss does not blanket this source entrance")
	game.runtime.s.bossActive = false; game.runtime.s.bossKind = "kingdom"
	_check(game.resolve_interaction().is_empty() and not game.runtime.open_old_school().get("ok",false),"Kingdom kind blanket applies even without active flag")
	game.runtime.s.bossKind = ""
	# A lower-priority route is reachable and aimed at the same time.
	game.runtime.s.blockRoute = {"stops":["school_chain","block_news","park_fountain"],"cursor":0,"serial":1,"lastStopId":""}
	_place(CENTER+Vector2(26,26))
	game.camera.look_at(game.world.service_points.oldschool.target.lerp(game.world.service_points["route:school_chain"].target,0.5))
	_check(game.runtime.progression.current_stop().get("id") == "school_chain" and game.physics.can_reach_target("route:school_chain") and game._aimed(game.world.service_points["route:school_chain"].target),"nearby route supplies genuine lower-priority reach and aim witness")
	_check(game.resolve_interaction().get("kind") == "oldschool","Old School source priority wins before route scan")
	_key(KEY_E)
	var buttons: Array[Button] = _buttons()
	_check(buttons.size() == 2,"rank3 actual menu has exactly two source choices")
	if buttons.size() == 2:
		_check(buttons[0].text == "rip copper from the walls. (40% spawn risk.)" and buttons[1].text == "leave.","source labels survive Scene binding")
	var copper: float = game.runtime.p.copper; var count: int = game.runtime.state.npcs.size(); var seed: int = game.runtime.state.rng_seed
	_key(KEY_1)
	var actor: Dictionary = _actor()
	_check(not actor.is_empty() and game.runtime.state.npcs.size() == count+1,"real numbered first rip creates one canonical actor")
	_check(game.runtime.p.copper == copper and game.runtime.state.rng_seed == seed,"first rip pays no copper and draws no gameplay RNG")
	_check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"forced first encounter closes source modal")
	if not actor.is_empty():
		_check(actor.hp == 250 and actor.dmg == 35 and actor.w == 36 and actor.h == 28 and actor.isOsBrutus,"existing boss authority owns canonical encounter payload")
		_check(game.physics._clear(game.runtime.combat._geometry(actor),Vector2(actor.x,actor.y),false),"spawned body is clear in actual world physics")
		game._sync_model_nodes(0.0)
		_check(game.actors.has("os_brutus") and not str(game.actors.os_brutus.get_meta("visual_id","")).is_empty(),"spawn receives original authored visual through production sync")
		_check(game.actors.os_brutus.position.distance_to(Content.body_position(actor,game.Adapter.FEET)) < 0.001,"visual mirrors staged authoritative position")
	# Alive callback adds2copper and reopens; it cannot create a second record.
	_place(CENTER+Vector2(0,30)); _key(KEY_E); _key(KEY_1)
	_check(game.runtime.p.copper == copper+2 and game.runtime.state.npcs.size() == count+1 and game.runtime.s.mode == "dialogue","live Brutus repeats exact copper branch with one actor")
	_key(KEY_2)
	_check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"numbered interior leave closes capability")
	groups += 1
func _lifecycle() -> void:
	for mode: String in ["paused","title","dialogue"]:
		var page: Dictionary = _open()
		game.runtime.set_mode(mode)
		var before: Dictionary = _fingerprint()
		_check(not game.runtime.select_old_school(page.get("token"),"rip").get("ok",false) and _fingerprint() == before,"mode replacement invalidates old choice without changing destination:"+mode)
		game.runtime.set_mode("playing")
	var page: Dictionary = _open()
	var block: Vector2 = Content.to_source(game.world.service_points["smoke:block"].approach)
	_place(block,false)
	var newer: Dictionary = game.runtime.open_zone("block")
	_check(newer.get("ok",false) and newer.has("token"),"real other domain replaces Old School")
	var before: Dictionary = _fingerprint()
	_check(not game.runtime.select_old_school(page.get("token"),"rip").get("ok",false) and _fingerprint() == before,"old domain token preserves newer utility page")
	_check(game.runtime.select_utility(newer.get("token"),"leave").get("ok",false),"new page capability survives old token refusal")
	page = _open()
	var saved: Dictionary = game.runtime.snapshot()
	_check(game.runtime.restore(saved),"real composed restore accepts school-side save")
	before = _fingerprint()
	_check(not game.runtime.select_old_school(page.get("token"),"rip").get("ok",false) and _fingerprint() == before,"restore invalidates previous p/s capability")
	page = _open()
	_check(game.runtime.fresh(),"real composed fresh normalizes Bosses before next school open")
	before = _fingerprint()
	_check(not game.runtime.select_old_school(page.get("token"),"rip").get("ok",false) and _fingerprint() == before,"fresh invalidates previous p/s capability")
	page = _open()
	_check(page.get("ok",false),"school owner rebinds fresh epoch after real normalization")
	game.runtime.close_dialogue(); _place(CENTER+Vector2(0,30)); _key(KEY_E)
	var old_callback: Dictionary = game._option("old rip",game._choose.bind("oldschool",game.runtime.old_school.session._token,"rip"))
	game._pause(); before = _fingerprint(); old_callback.action.call()
	_check(_fingerprint() == before and game.runtime.s.mode == "paused","Scene menu generation rejects stale callback after pause")
	game._resume()
	groups += 1
func _corpse() -> void:
	var page: Dictionary = _open()
	_check(game.runtime.select_old_school(page.get("token"),"rip").get("ok",false),"fresh physical first encounter still available after lifecycle changes")
	var actor: Dictionary = _actor()
	_check(not actor.is_empty(),"fresh encounter actor exists for real death routing")
	if actor.is_empty(): return
	actor.hp = 0
	_check(game.runtime.handle_death("os_brutus"),"existing domain handles canonical Old School death")
	game.runtime.drain_events()
	_check(actor.dead and game.runtime.s.flags.osBrutusKilled and game.runtime.p.copper == 5,"real death preserves corpse and exact5copper reward")
	var count: int = game.runtime.state.npcs.size(); var copper: float = game.runtime.p.copper
	page = _open(); game.runtime.state.rng_seed = 1 # Existing LCG's first draw is below.4.
	var result: Dictionary = game.runtime.select_old_school(page.get("token"),"rip")
	_check(result.get("ok",false) and game.runtime.p.copper == copper+2 and game.runtime.state.npcs.size() == count,"retained corpse blocks cousin actor while normal copper still commits")
	_check(game.runtime.s.mode == "playing" and _actor().dead,"successful cousin roll closes with retained source corpse")
	var saves: int = 0
	for event: Dictionary in game.runtime.drain_events():
		if event.kind == "save_requested": saves += 1
	_check(saves == 0,"source corpse-hit branch has no immediate save")
	groups += 1
func _run() -> void:
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(500):
		await process_frame
		if game.ready_for_play: break
	_check(game.ready_for_play,"real FullScene reaches title")
	if not game.ready_for_play: await _finish(); return
	game.set_process(false); game.qa_mode = true; game.web_controls = false
	game.store.free(); game.store = MemoryStore.new(); game.add_child(game.store)
	game._new_game(); await physics_frame; await physics_frame
	_check(game.runtime.old_school != null and game.runtime.old_school.ready() and game.runtime._actors_enabled,"Old School uses real composed Bosses/Combat")
	_check(game.runtime.state.npcs.size() == 56,"physical test retains entire authored day-one roster")
	await _range_and_los(); _controls_and_spawn(); _lifecycle(); _corpse()
	await _finish()
func _finish() -> void:
	_check(groups == 4,"all4physical/controller/lifecycle/corpse groups completed")
	if game != null and game.sound != null:
		for voice: AudioStreamPlayer in game.sound.players:
			voice.stop(); voice.stream = null
	await create_timer(0.10).timeout
	if game != null: game.free(); game = null
	await process_frame; await process_frame
	if failures.is_empty() and checks >= 60:
		print("3D OLD SCHOOL PHYSICAL GATE: PASS (%d checks;actual44px/LOS/controller/spawn/epoch/corpse)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D OLD SCHOOL PHYSICAL GATE: FAIL (%d/%d checks;groups%d/4)" % [failures.size(),checks,groups]); quit(1)
