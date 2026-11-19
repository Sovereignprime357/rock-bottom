extends SceneTree
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
const EconomyFixtures = preload("res://tests/test_economy.gd")
class ReceiptObserverRig:
	extends "res://scripts/first_person_rig.gd"
	var observed: Array[StringName] = []
	func acknowledge(kind: StringName,success: bool = true,contact: bool = false,used_weapon: StringName = &"") -> void:
		observed.append(kind)
		super.acknowledge(kind,success,contact,used_weapon)
class DelayedStore:
	extends "res://scripts/save_store.gd"
	signal read_started
	signal release_read
	var response: Dictionary = {}
	var writes: Array[Dictionary] = []
	var concurrent_writes: int = 0
	func read_save() -> Dictionary:
		busy = true; read_started.emit()
		await release_read
		busy = false; return response.duplicate(true)
	func write_save(data: Dictionary) -> bool:
		if busy: concurrent_writes += 1; return false
		writes.append(data.duplicate(true)); return true
var game: Node3D
var checks: int = 0
var failures: Array[String] = []
var dave_wake_completed := false
var vendor_receipts_completed := false
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _place(point: Vector3,target: Vector3 = Vector3.INF) -> void:
	var center: Vector2 = Content.to_source(point)
	game.runtime.p.x = center.x-game.runtime.p.w*0.5; game.runtime.p.y = center.y-game.runtime.p.h*0.5
	game._sync_player()
	if target.is_finite(): game.camera.look_at(target)
func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event)
func _run() -> void:
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(500):
		await process_frame
		if game.ready_for_play: break
	check(game.ready_for_play,"actual full scene reaches title")
	if not game.ready_for_play: await _finish(); return
	for pair: Array in [["forward",KEY_W,KEY_UP],["back",KEY_S,KEY_DOWN],["left",KEY_A,KEY_LEFT],["right",KEY_D,KEY_RIGHT]]:
		for code: int in [pair[1],pair[2]]:
			var alias := InputEventKey.new(); alias.physical_keycode = code
			check(InputMap.action_has_event(pair[0],alias),"advertised movement alias exists: "+str(code))
	var input_sizes: Array = []
	for action: String in ["forward","back","left","right","sprint"]: input_sizes.append(InputMap.action_get_events(action).size())
	game._register_inputs()
	for index: int in range(input_sizes.size()):
		check(InputMap.action_get_events(["forward","back","left","right","sprint"][index]).size() == input_sizes[index],"input registration keeps existing events without duplicate aliases")
	game.set_process(false); game.qa_mode = true
	game.store.save_path = ProjectSettings.globalize_path("res://../.build/3d/full-scene-test-save.json")
	game.store.storage_key = "rockbottom_3d_full_test"
	check(game.actors.size() == 56 and game.missing_visuals.is_empty(),"all56real day-one instances have authored visuals")
	check(game.runtime._actors_enabled and game.runtime.combat != null and game.runtime.director != null,"one actual composed combat/director")
	for actor: Dictionary in game.runtime.state.npcs:
		check(game.physics._clear(game.runtime.combat._geometry(actor),Vector2(actor.x,actor.y),false),"initial actor is physically clear before first tick:"+actor.id)
	check(game.runtime.s.mode == "title" and game.hud.modal.visible,"startup title mode agrees with surface")
	check(game.fixture_motion.inspect().built and game.world.dynamic_fixture_motion,"actual full scene adopts source fixture anchors")
	check(is_instance_valid(game._pete_food) and game._pete_food.name == "hot_pocket","steam binds the actual retained food prop")
	game._sync_fixture_motion(150,1600)
	check(not game.fixture_motion.inspect().tv_visible,"source fixture motion is hidden at title")
	game._new_game()
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"new game closes menu once")
	var fixture_before: Dictionary = game.runtime.snapshot()
	game._sync_fixture_motion(0,0)
	check(game.fixture_motion.inspect().tv_visible and not game.fixture_motion.inspect().sample.tv_on,"world fixture projection uses supplied monotonic clock")
	game._sync_fixture_motion(100,1600)
	check(game.fixture_motion.inspect().sample.tv_on and not game.fixture_motion.inspect().sample.shadow_visible,"independent visual and Unix clocks reach source boundaries")
	check(game.runtime.snapshot() == fixture_before,"fixture projection cannot mutate shared source state")
	var fixture_day: float = game.runtime.s.dayTime
	game.runtime.s.dayTime = 0.9
	game._sync_model_nodes(0.0)
	check(not game.actors.pete.visible and not game._pete_food.is_visible_in_tree(),"actual Day owner hides Pete and food during source night")
	var night_before: Dictionary = game.runtime.snapshot()
	check(game._sync_fixture_motion(400,1600) and game.fixture_motion.inspect().steam_visible,"actual normal night still renders steam through the counter fallback")
	var counter: Dictionary = game.world.fixture_motion_bindings().pawn_counter
	var counter_basis: Basis = counter.transform.basis.orthonormalized()
	var expected_steam: Vector3 = counter.transform*Vector3(0,counter.size.y*0.5,0)+counter_basis.x*sin(1.0)*0.08+Vector3.UP*0.125
	check(game.fixture_motion._steam.global_position.distance_to(expected_steam) < 0.00001,"live night steam uses the existing pawn service aperture")
	check(game.runtime.snapshot() == night_before,"night fixture fallback cannot change actor or source state")
	for boundary: float in [0.25,0.75]:
		game.runtime.s.dayTime = boundary; game._sync_model_nodes(0.0); game._sync_fixture_motion(400,1600)
		check(game.actors.pete.visible and not game.fixture_motion.inspect().steam_visible,"strict night boundary keeps daytime Pete without steam: "+str(boundary))
	game.runtime.s.dayTime = fixture_day; game._sync_model_nodes(0.0); game._sync_fixture_motion(100,1600)
	await physics_frame
	game._process(1.0/60.0)
	check(game.player.position.distance_to(Content.to_world(game.runtime.state.player_center(),game.Adapter.FEET)) < 0.00001,"player view mirrors the authoritative controller")
	var wall_view: Dictionary = game.wall_marking_view.inspect()
	check(wall_view.requested == game.runtime.s.graffiti.size()+game.runtime.s.posters.size() and wall_view.placed == wall_view.requested and wall_view.rejected.is_empty(),"actual fresh source layouts all bind audited facade panels")
	var wall_builds: int = wall_view.builds
	game._process(0.0)
	check(game.wall_marking_view.inspect().builds == wall_builds,"unchanged actual scene does not rebuild wall text resources")
	check(game.finds.has("cp_intro_remember") and game.finds.cp_intro_remember.source_id == "cp_intro_remember" and game.finds.cp_intro_remember.presentation_kind == "money","actual intro pickup uses the original cached find presenter")
	var initial_weather := {"dayTime":game.runtime.s.dayTime,"weather":game.runtime.s.weather}
	game.runtime.s.dayTime = 0.65; game.runtime.s.weather = "rain"
	var weather_before: Dictionary = game.runtime.snapshot()
	game._process(0.0)
	check(game.weather_view.inspect().profile.night == 0.0 and game.weather_view.rain.visible,"actual full scene uses source daytime curve and current rain state")
	check(game.runtime.snapshot() == weather_before,"zero-time weather presentation cannot change source state")
	check(game._sole_shadow_light(),"actual full-world fixtures permit the sole-sun pose proof")
	var added_shadow := OmniLight3D.new(); added_shadow.shadow_enabled = true; game.add_child(added_shadow)
	check(not game._sole_shadow_light(),"a newly added actual shadow light immediately disables pose rejection")
	added_shadow.shadow_enabled = false
	check(game._sole_shadow_light(),"current light flags are read without stale certification")
	added_shadow.free()
	check(game._sole_shadow_light(),"removed lights leave no stale registry entry")
	check(game.ownership_view.inspect().built and game.world.dynamic_ownership,"actual full scene owns the live ownership bank")
	check(game.kingdom_view.inspect().built,"actual full scene owns the four Kingdom banner and nine-mark bank")
	var kingdom_before: Dictionary = game.runtime.s.kingdom.duplicate(true)
	var clan: Dictionary = Content.definition("src/systems/campaigns.js","KINGDOM_CLANS",{}).blue_tarp
	game.runtime.s.kingdom.stage = clan.marksStage; game.runtime.s.kingdom.marks = 1; game._process(0.0)
	var kingdom_facts: Dictionary = game.kingdom_view.inspect().facts
	check(kingdom_facts.marks["blue_tarp:0"].done and kingdom_facts.marks["blue_tarp:1"].visible,"current source stage displays completed and pending Kingdom marks")
	game.runtime.s.kingdom = kingdom_before; game._process(0.0)
	check(not game.kingdom_view.inspect().facts.marks["blue_tarp:0"].visible,"stage replacement removes old marks without rebuilding the world")
	var office_before: Dictionary = game.runtime.s.office.duplicate(true)
	var claims_before: Dictionary = game.runtime.s.districtClaims.duplicate(true)
	game.runtime.s.office.owned = true; game.runtime.s.office.upgrades.desk = true
	for site: Dictionary in Content.definition("src/systems/campaigns.js","CLAIM_SITES",[]): game.runtime.s.districtClaims[site.id] = true
	game._process(0.0)
	var ownership: Dictionary = game.ownership_view.inspect()
	check(ownership.facts.office.title == "PAPER AUTHORITY" and ownership.facts.office.paper_count == 6 and ownership.facts.office.trim,"current model projects all eleven claims and desk papers")
	game.runtime.s.office = office_before; game.runtime.s.districtClaims = claims_before; game._process(0.0)
	check(not game.ownership_view.inspect().facts.office.owned and game.ownership_view.inspect().facts.office.claims == 0,"revoked model ownership clears facade upgrades without a new world")
	var source_dog: Dictionary = {}
	for record: Dictionary in game.runtime.state.npcs:
		if record.id == "scrap_dog": source_dog = record; break
	check(game.dog_leash.inspect().active,"actual living original dog binds its current weighted collar to the real post")
	var chained_before: Variant = source_dog.get("chained")
	source_dog.chained = false; game._sync_model_nodes(0.016)
	check(game.dog_leash.inspect().active,"living unchained original retains the source leash quirk")
	source_dog.dead = true; game._sync_model_nodes(0.0)
	check(not game.dog_leash.inspect().active,"dead/freed original removes leash rather than binding a follower")
	source_dog.dead = false; source_dog.chained = chained_before; game._sync_model_nodes(0.016)
	var collar: Node3D = game.actors.scrap_dog.get_meta("leash_collar")
	var leash_points: PackedVector3Array = game.dog_leash.inspect().points
	check(game.dog_leash.to_global(leash_points[6]).distance_to(collar.global_position) < 0.00001,"scene chain endpoint follows the actual current animated collar")
	game.runtime.s.borderGlowT = 600.0; game.runtime.s.borderGlowColor = "#a04848"; game.runtime.s.borderGlowRect = {"x":0,"y":0,"w":100,"h":100}
	game._process(0.0)
	check(game.hud.district_border.inspect().visible and game.hud.district_border.inspect().alpha == 0.55,"separate district perimeter projects source timing/color")
	game._pause(); game._process(0.25)
	check(game.runtime.s.borderGlowT == 600.0,"paused composition cannot consume border time")
	game._resume(); game.runtime.s.borderGlowRect = {}; game._process(0.0)
	check(not game.hud.district_border.inspect().visible,"missing source rectangle hides border even with remaining time")
	game.runtime.s.borderGlowT = 0.0
	check(game.dynamic_emitters.inspect().allocated_lights == 6 and game.dynamic_emitters.inspect().dynamic_shadows == 0,"actual full scene owns exactly six shadowless moving fixtures")
	check(game.dynamic_emitters.inspect().cop_count == 1,"resident Horse Cop binds its actual rider cap")
	game.runtime.p.rockedT = 1000
	game._process(0.0)
	check(game.dynamic_emitters.inspect().player_active and game._ember_anchor.is_visible_in_tree(),"actual current high enables visible mouth fixture and light together")
	check(game.dynamic_emitters._player.global_position.distance_to(game._ember_anchor.global_position) < 0.00001,"player light follows the actual authored ember tip")
	game.hands.acknowledge(&"interact"); game._sync_dynamic_emitters(350.0)
	check(not game.dynamic_emitters.inspect().player_active,"acknowledged hand gesture stows actual fixture and light")
	game.runtime.p.rockedT = 0; game.runtime.p.hitterHigh = true
	game.hands.reset(); game._hand_context.clear(); game._process(0.0)
	check(game.dynamic_emitters.inspect().player_active,"current hitter high restores source light independently of weapon")
	game._pause(); game._process(0.0)
	check(not game.dynamic_emitters.inspect().player_active,"actual pause hides mouth fixture and its field")
	game.runtime.p.hitterHigh = false; game._resume(); game._process(0.0)
	check(not game.dynamic_emitters.inspect().player_active,"ending high leaves no stale player light")
	game.runtime.s.dayTime = initial_weather.dayTime; game.runtime.s.weather = initial_weather.weather
	game._process(0.0)
	var initial_objective: Dictionary = game.runtime.guidance.primary_objective()
	var objective_target := Content.to_world(Vector2(initial_objective.x,initial_objective.y),0.08)
	check(game.hud._guidance_camera_ref.get_ref() == game.camera,"projected guidance binds actual player camera")
	check(game._guidance_target_visible(objective_target),"opening objective has actual clear guidance ray")
	var marker_before: Dictionary = game.runtime.snapshot()
	var marker_blocker := StaticBody3D.new(); marker_blocker.collision_layer = 1; marker_blocker.collision_mask = 0
	var marker_shape := CollisionShape3D.new(); var marker_box := BoxShape3D.new(); marker_box.size = Vector3.ONE*0.25
	marker_shape.shape = marker_box; marker_blocker.add_child(marker_shape); game.world.add_child(marker_blocker)
	marker_blocker.global_position = game.camera.global_position.lerp(objective_target,0.5)
	await physics_frame; await physics_frame
	check(not game._guidance_target_visible(objective_target),"unrelated live wall blocks informational target ray")
	game.hud._refresh_guidance(); game.hud._project_guidance()
	check(game.hud._target_visibility == 0 and game.hud.guidance_overlay.visible,"actual blocked target reaches projected HUD without claiming clear access")
	check(game.runtime.snapshot() == marker_before,"guidance visibility and projection cannot mutate gameplay")
	marker_blocker.free(); await physics_frame
	check(game._guidance_target_visible(objective_target),"removing actual blocker restores guidance visibility")
	check(not game._guidance_target_visible(Vector3.INF),"invalid guidance target fails closed")
	for record: Dictionary in game.runtime.state.npcs:
		check(game.actors[record.id].position.distance_to(Content.body_position(record,game.Adapter.FEET)) < 0.0001,"source actor position:"+record.id)
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "paused" and game.hud.modal.visible,"Escape opens pause")
	var timer: float = game.runtime.s.dayTime
	game._process(0.1)
	check(game.runtime.s.dayTime == timer,"pause does not advance model")
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"second desktop Escape resumes once")
	game.web_controls = true; game.capture_acquired = false
	game._sync_mouse_capture(false)
	check(game.runtime.s.mode == "playing","initial/refused Web capture keeps game playable")
	game._sync_mouse_capture(true); game._sync_mouse_capture(false)
	check(game.runtime.s.mode == "paused","losing acquired Web capture pauses")
	_key(KEY_ESCAPE)
	check(game.runtime.s.mode == "paused","Web Escape does not recapture from pause")
	game._resume(); game.web_controls = false
	for browser_controls: bool in [false,true]:
		game.web_controls = browser_controls
		for shortcut: int in [KEY_Q,KEY_I]:
			_key(shortcut)
			check(game.runtime.s.mode == "dialogue" and game.ledger_key == shortcut and game.hud.modal.visible,"ledger opens with its exact close key")
			var repeated := InputEventKey.new(); repeated.physical_keycode = shortcut; repeated.pressed = true; repeated.echo = true
			game._unhandled_input(repeated)
			check(game.runtime.s.mode == "dialogue","held ledger shortcut cannot immediately close")
			_key(KEY_I if shortcut == KEY_Q else KEY_Q)
			check(game.runtime.s.mode == "dialogue","other ledger key does not change the open page")
			_key(shortcut)
			check(game.runtime.s.mode == "playing" and game.ledger_key == 0 and not game.hud.modal.visible and not game.capture_acquired,"same ledger key resumes once on native and Web")
			_key(shortcut); _key(KEY_ESCAPE)
			check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"visible journal Escape close instruction works on native and Web")
	game._ledger(false); game._pause(); _key(KEY_Q)
	check(game.runtime.s.mode == "paused" and game.ledger_key == 0,"new menu clears ledger shortcut capability")
	game._resume(); game.web_controls = false
	_key(KEY_P); game.hud.update_runtime(game.runtime)
	check(game.runtime.communications.snapshot().visible and game.hud.feed_panel.visible and game.runtime.s.mode == "playing","P opens real phone without freezing world")
	_key(KEY_P); game.hud.update_runtime(game.runtime)
	check(not game.hud.feed_panel.visible,"P closes source phone")
	var count: Array[int] = [0]
	game._begin_menu()
	var stale: Dictionary = game._option("old",func(): count[0] += 1)
	game._begin_menu(); stale.action.call()
	check(count[0] == 0,"stale scene callbacks cannot execute")
	var pickup: Dictionary = game.world.service_points["cash:cp_intro_remember"]
	_place(pickup.approach,pickup.target)
	var action: Dictionary = game.resolve_interaction()
	check(action.get("kind") == "cash","cash prompt consumes actual closest low target")
	game.interact()
	check(game.runtime.p.cash == 10,"actual scene pickup resolves source intro cash")
	var tony: Dictionary = game.world.service_points.tony
	_place(tony.approach,tony.target)
	game.runtime.p.stunT = 300
	check(game.interact().is_empty() and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"stunned E cannot open vendor or pause the world")
	game.runtime.p.stunT = 0
	action = game.interact()
	check(action.get("id") == "tony" and game.runtime.s.mode == "dialogue","aimed Tony opens real vendor menu")
	var buttons: Array[Button] = []
	for child: Node in game.hud.menu_box.get_children():
		if child is Button: buttons.append(child)
	check(buttons.size() == 5,"vendor renders each source choice once including Leave")
	if not buttons.is_empty(): buttons[0].pressed.emit()
	check(game.runtime.p.rocks == 1 and game.runtime.p.cash == 0 and game.runtime.s.mode == "playing","real menu buy commits once and closes")
	check(game.hands.action == &"receipt","actual committed vendor menu purchase reaches the existing hand receipt")
	var block: Dictionary = game.world.service_points["smoke:block"]
	_place(block.approach)
	game.camera.rotation = Vector3.ZERO
	action = game.interact()
	check(action.get("kind") == "smoke" and action.id == "block","whole Block zone verb follows NPC priority without marker aim")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("smoke a rock. (-1 rock"): child.pressed.emit(); break
	check(game.runtime.p.rockedT == 18000 and game.runtime.p.rocks == 0 and game.runtime.s.flags.introDone,"actual smoke menu starts single18s high and completesintro")
	check(game.hands.action == &"smoke","accepted source action reaches hand rig")
	game._ledger(true)
	check(game.runtime.s.mode == "dialogue" and game.hud.modal.visible,"inventory is modal readonly full ledger")
	var before: Dictionary = game.runtime.snapshot()
	check(game.hud.inventory_copy(game.runtime).contains("equipment"),"inventory displays actual equipment")
	check(game.runtime.snapshot() == before,"inventory rendering cannot mutate resources")
	game._resume()
	game._ledger(false); check(game.hud.modal.visible,"quest/hustle ledger renders actual state"); game._resume()
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game._request_save(game.runtime.snapshot())
	while game.saving or not game.pending_save.is_empty(): await process_frame
	var saved: Dictionary = await game.store.read_save()
	check(saved.get("schema") == 2 and saved.get("format") == "rock-bottom-full-state","isolated full scene persistence stores full schema")
	game.runtime.p.cash = 73
	await game._load()
	check(game.runtime.p.cash == 0 and game.runtime.s.mode == "paused","load restores owned state then awaits deliberate Continue")
	check(game.hud.modal.visible,"load cannot leave input captured behind a modal")
	game._resume()
	check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"Continue after load is playable")
	var marking_draws: int = game.runtime.wall_markings.inspect().draws
	await game._load()
	check(game.runtime.wall_markings.inspect().draws == marking_draws and game.runtime.s.graffiti == saved.state.graffiti,"actual placed load preserves valid raw wall records without reroll")
	var legacy_walls: Dictionary = saved.duplicate(true)
	legacy_walls.state.erase("graffiti"); legacy_walls.state.erase("posters")
	await game.store.write_save(legacy_walls); await game._load()
	check(game.runtime.wall_markings.inspect().draws > marking_draws and game.runtime.wall_markings.inspect().bound,"actual Scene load retains missing-field migration through placement normalization")
	await _test_bounded_wall_load(saved)
	for kind: String in ["missing","null","scalar","empty"]:
		var hustle_save: Dictionary = saved.duplicate(true)
		if kind == "missing": hustle_save.state.erase("hustles")
		else: hustle_save.state.hustles = [] if kind == "empty" else (17 if kind == "scalar" else null)
		await game.store.write_save(hustle_save); await game._load()
		check(game.runtime.s.hustles.size() == (0 if kind == "empty" else 3),"actual placement-normalized load preserves hustle fallback decision: "+kind)
	await game.store.write_save(saved); await game._load(); game._resume()
	game.runtime.p.cash = 23
	await game.store.write_save({"schema":900,"cash":999})
	await game._load()
	check(game.runtime.p.cash == 23,"invalid save cannot erase current progress")
	game._resume()
	var pinky: Dictionary = game.world.service_points.pinky
	_place(pinky.approach,pinky.target)
	action = game.interact()
	check(action.get("kind") == "street" and action.id == "pinky","actual aimed Pinky uses full Street menu")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("buy 1 house cut"):
			child.pressed.emit(); break
	check(game.runtime.p.dirtySupplies == 1 and game.runtime.s.mode == "playing","Pinky supply choice commits and releases modal")
	var singer: Dictionary = game.world.service_points.karaoke
	_place(singer.approach,singer.target)
	action = game.interact()
	check(action.get("id") == "karaoke","actual Karaoke interaction resolves")
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("sing a song"):
			child.pressed.emit(); break
	check(game.runtime.rhythm.is_active() and game.runtime.s.mode == "dialogue","returned activities domain keeps actual rhythm modal")
	var first_index: int = game.runtime.rhythm._index
	_key(KEY_1)
	check(game.runtime.rhythm._index == first_index+1 and game.runtime.rhythm.is_active(),"source number shortcut advances exactly one Karaoke note")
	_key(KEY_ESCAPE)
	check(not game.runtime.rhythm.is_active() and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"Escape cancels rhythm and releases actual menu")
	var rig: Dictionary = game.actors.busker.get_node("Art").get_meta("roster_rig")
	game.runtime.s.hitPause = 100
	var pose_clock: float = rig.time
	game._process(1.0/60.0)
	check(rig.time == pose_clock,"hitpause freezes actual actor pose clock")
	game.runtime.s.hitPause = 0
	var rng: int = game.runtime.state.rng_seed
	game._sync_model_nodes(1.0/60.0)
	check(rig.time > pose_clock and game.runtime.state.rng_seed == rng,"identity idle pose advances without model RNG")
	await _test_cooking_controls()
	_test_companion_controls()
	_test_office_controls()
	_test_world_prop_controls()
	_test_kingdom_controls()
	_test_room_views()
	_test_utility_controls()
	_test_interactive_controls()
	await _test_cart_controls()
	await _test_dave_wake_controls()
	check(dave_wake_completed,"Dave wake scene regression reached its actual completion tail")
	_test_site_menu()
	await _load_arrival_race(false)
	await _load_arrival_race(true)
	_test_ending_receipts()
	await _test_vendor_receipts()
	check(vendor_receipts_completed,"receipt source/event/rig regression completed without script abort")
	await _finish()

func _receipt_fixture(vendor: String,action: String) -> Dictionary:
	# Reuse the existing economy gate's bounded spatial/boss seams; no world-play claim.
	var owner: RefCounted = EconomyFixtures.State.new()
	var spatial: RefCounted = EconomyFixtures.Spatial.new()
	var boss: RefCounted = EconomyFixtures.Boss.new(owner)
	var vendors: RefCounted = EconomyFixtures.Vendors.new(owner,spatial,null,boss)
	owner.p.cash = 200; owner.p.copper = 3; owner.p.rank = 3; owner.p.cred = 100
	owner.p.faction.scrap = 30; owner.s.quests.intro_tony.available = false
	owner.p.inventory.append({"id":"license","n":"license plate","q":1})
	owner.p.inventory.append({"id":"junk","n":"a piece of junk","q":1})
	if action == "torch_again": owner.s.flags.peteTorchSold = true
	if action == "swap_tools": owner.equip_tool("crowbar"); owner.equip_tool("propane_torch")
	for body: Dictionary in owner.npcs:
		if body.id == vendor:
			owner.p.x = float(body.x)+(float(body.w)-float(owner.p.w))*0.5
			owner.p.y = float(body.y)+(float(body.h)-float(owner.p.h))*0.5
			break
	return {"owner":owner,"spatial":spatial,"boss":boss,"vendors":vendors}

func _receipt_events(owner: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in owner.events:
		if event.kind == "vendor_action": result.append(event.duplicate(true))
	return result

func _project_receipt_events(events: Array[Dictionary],rig: ReceiptObserverRig) -> void:
	var before: Dictionary = game.runtime.snapshot()
	var seed: int = game.runtime.state.rng_seed
	game.runtime._outbox.append_array(events.duplicate(true))
	game._consume_events()
	check(game.runtime.snapshot() == before and game.runtime.state.rng_seed == seed,"receipt projection changes no source state or RNG")
	var count: int = rig.observed.size()
	game._consume_events()
	check(rig.observed.size() == count,"second event drain cannot replay a transaction gesture")

func _test_vendor_receipts() -> void:
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game.runtime.fresh(); game._resume(); game.runtime.drain_events()
	var original: Node3D = game.hands
	var original_visible: bool = original.visible
	var rig := ReceiptObserverRig.new(); rig._build(); rig.reset()
	original.get_parent().add_child(rig); original.hide(); game.hands = rig
	game._hand_context.clear(); game._sync_hand_context()
	var paper: MeshInstance3D = rig.get_node("left_arm/forearm/wrist/receipt/paper")
	var paper_mesh: Mesh = paper.mesh; var paper_material: Material = paper.material_override
	var completed := 0
	var positive: Array = [["tony","buy_rock"],["tony","short"],
		["yuri","sell_copper"],["yuri","sell_all_copper"],["yuri","rent_shed"],
		["pete","sell_copper"],["pete","sock"],["pete","sell_license"],["pete","sell_junk"],
		["pete","buy_food"],["pete","buy_torch"],["pete","buy_crowbar"],["pete","loan"]]
	for pair: Array in positive:
		var f: Dictionary = _receipt_fixture(pair[0],pair[1])
		var menu: Dictionary = f.vendors.open(pair[0])
		check(menu.get("ok",false),"real vendor fixture opens "+str(pair))
		if not menu.get("ok",false): continue
		f.owner.events.clear()
		var cash: int = f.owner.p.cash
		var result: Dictionary = f.vendors.select(menu.token,pair[1])
		var events: Array[Dictionary] = _receipt_events(f.owner)
		check(result.get("ok",false) and f.owner.p.cash != cash and events.size() == 1,"one economically committed source event "+str(pair))
		var committed: Dictionary = f.owner.snapshot(); var event_copy: Array = events.duplicate(true)
		rig.reset(); rig.observed.clear(); _project_receipt_events(events,rig)
		check(rig.observed == [&"receipt"] and rig.action == &"receipt","one existing receipt acknowledgement "+str(pair))
		check(f.owner.snapshot() == committed and events == event_copy,"presentation preserves committed producer and event payload "+str(pair))
		rig.tick(0.08,Vector3.ZERO,false); rig.tick(0.08,Vector3.ZERO,false)
		check(paper.is_visible_in_tree() and is_equal_approx(rig.action_phase,0.5),"existing paper is visible at original receipt midpoint")
		var phase: float = rig.action_phase; rig.tick(0.0,Vector3.ZERO,false)
		check(rig.action_phase == phase,"zero admitted time cannot spend receipt recovery")
		rig.tick(0.08,Vector3.ZERO,false); rig.tick(0.08,Vector3.ZERO,false)
		check(rig.action.is_empty() and not paper.is_visible_in_tree(),"original0.32second recovery hides paper")
		completed += 1
	check(completed == 13,"all thirteen committed pair witnesses completed")
	var excluded: Array = [["tony","leave"],["tony","negotiate"],["tony","challenge"],
		["yuri","brutus"],["yuri","dog"],["pete","torch_again"],["pete","swap_tools"]]
	var negatives := 0
	for pair: Array in excluded:
		var f: Dictionary = _receipt_fixture(pair[0],pair[1]); var menu: Dictionary = f.vendors.open(pair[0])
		check(menu.get("ok",false),"excluded real vendor fixture opens "+str(pair))
		if not menu.get("ok",false): continue
		f.owner.events.clear()
		var result: Dictionary = f.vendors.select(menu.token,pair[1])
		check(result.get("ok",false),"source nonreceipt path really succeeds "+str(pair))
		rig.reset(); rig.observed.clear(); _project_receipt_events(_receipt_events(f.owner),rig)
		check(rig.observed.is_empty() and rig.action.is_empty(),"success alone cannot fabricate economic receipt "+str(pair))
		if pair[1] == "challenge": check(f.boss.starts == 1 and f.owner.s.bossActive,"actual source challenge dispatched its existing boss seam")
		negatives += 1
	check(negatives == 7,"all seven excluded successful paths completed")
	for stale: bool in [false,true]:
		var f: Dictionary = _receipt_fixture("tony","buy_rock"); var menu: Dictionary = f.vendors.open("tony")
		if stale: check(f.vendors.select(menu.token,"buy_rock").ok,"stale witness first transaction really commits")
		else: f.owner.p.cash = 0
		f.owner.events.clear()
		var result: Dictionary = f.vendors.select(menu.token,"buy_rock")
		check(not result.ok and _receipt_events(f.owner).is_empty(),"refused/stale token emits no committed event: "+str(stale))
		rig.reset(); rig.observed.clear(); _project_receipt_events(_receipt_events(f.owner),rig)
		check(rig.observed.is_empty(),"refused/stale request cannot acknowledge receipt")
	for payload: Dictionary in [{},{"ok":false,"vendor":"tony","action":"buy_rock"},
		{"ok":1,"vendor":"tony","action":"buy_rock"},{"ok":"true","vendor":"tony","action":"buy_rock"},
		{"ok":true,"vendor":"tony","action":"loan"},{"ok":true,"vendor":"pete","action":"rent_shed"},
		{"ok":true,"vendor":"TONY","action":"buy_rock"},{"ok":true,"vendor":"unknown","action":"buy_rock"},
		{"ok":true,"vendor":null,"action":"buy_rock"},{"ok":true,"vendor":"tony","action":["buy_rock"]}]:
		check(not Scene._vendor_receipt(payload),"malformed or wrong-vendor action refuses atomically "+str(payload))
	var event: Dictionary = {"kind":"vendor_action","payload":{"ok":true,"vendor":"pete","action":"sock"}}
	rig.reset(); rig.observed.clear(); rig.acknowledge(&"punch",true,true,&"fists")
	var punch_phase: float = rig.action_phase; rig.observed.clear()
	_project_receipt_events([event],rig)
	check(rig.observed == [&"receipt"] and rig.action == &"punch" and rig.action_phase == punch_phase,"successful transaction cannot interrupt an accepted punch")
	rig.reset(); rig.observed.clear()
	_project_receipt_events([event,{"kind":"player_attack","payload":{"connected":true,"used_weapon":"fists"}}],rig)
	check(rig.observed == [&"receipt",&"punch"] and rig.action == &"punch","original batch ordering lets later accepted attack replace receipt immediately")
	var third: Dictionary = _receipt_fixture("tony","short"); third.owner.p.tonyOffenses = 2
	var third_menu: Dictionary = third.vendors.open("tony"); third.owner.events.clear()
	check(third.vendors.select(third_menu.token,"short").ok and third.boss.starts == 1 and third.owner.p.cash == 195,"third short retains actual paid boss consequence")
	rig.reset(); rig.observed.clear(); _project_receipt_events(_receipt_events(third.owner),rig)
	check(rig.observed == [&"receipt"],"third short is still one committed money transaction")
	rig.reset()
	check(paper.mesh == paper_mesh and paper.material_override == paper_material and not paper.is_visible_in_tree(),"reset clears presentation and retains original paper resources")
	game.hands = original; original.visible = original_visible; game._hand_context.clear(); game._sync_hand_context(); rig.free()
	vendor_receipts_completed = true


func _test_bounded_wall_load(saved: Dictionary) -> void:
	# Process is disabled: inspect restored authority, then the caller reloads ordinary
	# layouts before any world draw. This witness creates no thousand-label projection.
	check(not game.is_processing(),"bounded-save regression runs before presentation")
	var oversized: Dictionary = saved.duplicate(true)
	oversized.state.graffiti = []
	for index: int in range(1025): oversized.state.graffiti.append(saved.state.graffiti[0].duplicate(true))
	var nested: Dictionary = {"end":"too deep"}
	for depth: int in range(12): nested = {"next":nested}
	var row: Dictionary = {}
	for index: int in range(32): row[str(index)] = index
	var bulk: Array = []
	for index: int in range(1025): bulk.append(row.duplicate())
	oversized.state.posters = [{"text":"p".repeat(4097),"nested":nested,"bulk":bulk}]
	await game.store.write_save(oversized)
	var raw: Dictionary = await game.store.read_save()
	var normalized := Scene.Runtime.State.new()
	check(normalized.restore(raw).ok,"actual oversized JSON uses the ordinary State decoder")
	var builds: int = game.wall_marking_view.inspect().builds
	await game._load()
	check(game.runtime.s.graffiti == normalized.s.graffiti and game.runtime.s.graffiti.size() == 1024 and game.runtime.s.posters == normalized.s.posters,"actual placed load preserves normalized nested wall values rather than reinserting raw arrays")
	check(game.wall_marking_view.inspect().builds == builds,"oversized load regression does not construct wall presentation resources")
	await game.store.write_save({"schema":1,"state":"legacy unrelated value"}); await game._load()
	check(game.runtime.wall_markings.inspect().bound and game.runtime.s.migration.from_schema == 1,"actual placed schema1 load ignores scalar legacy state")

func _test_ending_receipts() -> void:
	# Staged source events prove the facade/continuation only, not boss balance.
	game.runtime.fresh(); game._resume(); game.runtime.drain_events()
	var player_epoch: Dictionary = game.runtime.p; var state_epoch: Dictionary = game.runtime.s
	game.runtime.p.cash = 37; game.runtime.s.routesCompleted = 4
	for item: Dictionary in [
		{"payload":{"kind":"tony"},"title":"CRACK LORD SUPREME","copy":"the corner is yours · you get tuesdays and thursdays"},
		{"payload":{"kind":"coop"},"title":"TUESDAYS AND THURSDAYS","copy":"you and stripe split the corner · you get the slow days"},
		{"payload":{"kind":"kingdom"},"title":"ONE CRACKLORD","copy":"the kingdom is four curbs and a ditch · the throne is a folding chair"},
		{"payload":{"title":"THE BUS","day":30,"rocks_smoked":17,"cred":88},"title":"THE BUS","copy":"days: 30 · rocks smoked: 17 · cred: 88"}
	]:
		game.runtime.s.mode = "ending"; game.runtime.s.endingContinue = true
		game.runtime.state.emit_event("ending_requested",item.payload); game._consume_events()
		check(game.hud.menu_box.get_child(0).text == item.title and item.copy in game.hud.menu_box.get_child(1).text,"source ending receipt preserves its committed kind and counters:"+item.title)
		check(("vibekoded · the possum stayed" if item.title == "THE BUS" else "vibekoded · the possum still knows") in game.hud.menu_box.get_child(1).text,"source ending footer:"+item.title)
		game.saving = true; _key(KEY_SPACE)
		check(game.runtime.s.mode == "ending" and game.runtime.s.endingContinue,"Space cannot bypass ending save ownership")
		game.saving = false; game.pending_save = {"pending_fixture":true}; _key(KEY_SPACE)
		check(game.runtime.s.mode == "ending","Space cannot bypass queued ending save")
		game.pending_save.clear(); Input.action_press("forward")
		if item.title == "THE BUS": _press_prefix("return to the block.")
		else: _key(KEY_SPACE)
		check(game.runtime.s.mode == "playing" and not game.runtime.s.endingContinue and game.runtime.s.get("endingSavePromise") == null and not game.hud.modal.visible,"ending button/Space clears source continuation and closes receipt")
		check(not Input.is_action_pressed("forward") and is_same(game.runtime.p,player_epoch) and is_same(game.runtime.s,state_epoch) and game.runtime.p.cash == 37 and game.runtime.s.routesCompleted == 4,"ending continuation releases movement and retains actual progress/epoch")
		check(game.hud.receipt.text == "the block is still here.\nthe clipboard has another sheet." and is_equal_approx(game.hud.receipt_time,2.4),"ending continuation emits exact source2400ms receipt")
		game.runtime.drain_events(); game._continue_ending()
		check(game.runtime.drain_events().is_empty(),"repeated ending continuation emits nothing")

func _test_cart_controls() -> void:
	game.runtime.fresh(); game._resume(); game._sync_model_nodes(0.0)
	await physics_frame; await physics_frame
	check(game.world.dynamic_cart and game.runtime._cart_enabled and game.cart_view != null,"production cart has one dynamic projection")
	var id: String = game.runtime.travel._cart_id
	var service: Dictionary = game.world.service_points[id]
	_place(service.approach)
	var direction: Vector3 = service.target-game.camera.global_position
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.camera.rotation = Vector3(game.pitch,0,0)
	check(game.resolve_interaction().get("kind") == "cart","actual source approach and aim resolve cart E")
	var hp: float = game.runtime.p.hp
	_key(KEY_E)
	check(game.runtime.p.cartMounted and game.runtime.p.maxHp == 110 and game.runtime.p.hp == hp,"actual E mounts once and changes max HP without healing")
	check(game.cart_view.parked_body().collision_layer == 0 and not game.world.service_points.has(id),"accepted mount immediately removes parked body and service")
	game.pitch = -0.7; game.camera.rotation = Vector3(-0.7,0,0)
	game._sync_model_nodes(0.0); game._sync_hand_context()
	check(not game._hand_context.cart_grips.is_empty(),"downward view supplies actual handle markers to the hand rig")
	var before: Dictionary = game.runtime.travel.cart_record()
	var yaw: float = game.player.rotation.y
	game._pause(); game._process(0.1)
	check(game.runtime.travel.cart_record() == before and game.runtime.p.cartMounted,"pause preserves mounted source cart record")
	game._resume(); game.player.rotation.y = yaw
	# Looking above every nearby service must still allow source mounted dismount.
	game.pitch = 1.15; game.camera.rotation = Vector3(1.15,0,0)
	check(game.resolve_interaction().get("kind") == "cart","mounted E falls through to cart without aiming at it")
	_key(KEY_E)
	check(not game.runtime.p.cartMounted and game.cart_view.parked_body().collision_layer == 1,"actual E publishes a physically parked cart immediately")
	check(game._hand_context.cart_grips.is_empty(),"dismount explicitly clears previous hand grips")
	var parked: Dictionary = game.runtime.travel.cart_record()
	var snapshot: Dictionary = game.runtime.snapshot()
	check(game.runtime.restore(snapshot),"live cart scene restores source snapshot")
	check(game.runtime.travel.cart_record() == parked and game.cart_view.parked_body().collision_layer == 1,"same-process load keeps unsaved parked coordinates and republishes current body")
	check(game.runtime.fresh(),"live cart scene starts a fresh epoch")
	var reset: Dictionary = game.runtime.travel.cart_record()
	check(reset.x == 1000 and reset.y == 1600 and not game.runtime.p.cartMounted,"fresh returns unique cart to canonical spawn")
	game.player.rotation.y = 0; game.pitch = -0.04; game._resume(); game._sync_model_nodes(0.0)

func _dave_sleep_marker_count() -> int:
	if game.hud.actor_overlay == null or game.hud.actor_overlay._view == null: return -1
	var facts: Dictionary = game.hud.actor_overlay._view.snapshot(0.0)
	for row: Dictionary in facts.get("actors",[]):
		if row.get("id") != "dave": continue
		var count := 0
		for marker: Dictionary in row.get("markers",[]):
			if marker.get("kind") == "sleep": count += 1
		return count
	return -1

func _test_dave_wake_controls() -> void:
	# Only the player's existing service fixture is placed. Dave's source fields
	# and Director snapshots are produced by fresh/ordinary active model ticks.
	var fresh: bool = game.runtime.fresh()
	check(fresh,"Dave regression starts from an actual fresh source epoch")
	if not fresh: return
	game._consume_events(); game._resume(); game._sync_model_nodes(0.0)
	await physics_frame; await physics_frame
	var dave: Dictionary = game.runtime.combat.actor("dave")
	var service: Dictionary = game.world.service_points.get("dave",{})
	var ready: bool = not dave.is_empty() and dave.get("asleep") == true and game.actors.has("dave") and service.get("approach") is Vector3 and service.get("target") is Vector3
	if ready: ready = service.approach.is_finite() and service.target.is_finite()
	check(ready,"canonical fresh Dave is asleep with a real actor and service")
	if not ready: return
	_place(service.approach)
	var direction: Vector3 = service.target-game.camera.global_position
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.camera.rotation = Vector3(game.pitch,0,0)
	await physics_frame
	var stepped: bool = game.runtime.advance(1.0/60.0)
	check(stepped,"real active Runtime step publishes Dave's sleeping snapshot")
	if not stepped: return
	game._sync_model_nodes(1.0/60.0)
	var art: Node3D = game.actors.dave.get_node_or_null("Art")
	check(art != null and art.has_meta("roster_rig"),"Dave has the actual authored rig")
	if art == null or not art.has_meta("roster_rig"): return
	var rig: Dictionary = art.get_meta("roster_rig")
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	check(skeleton != null,"Dave's actual Skeleton3D exists")
	if skeleton == null: return
	var root_bone: int = skeleton.find_bone("root")
	check(root_bone >= 0,"Dave's actual skeleton has a root bone")
	if root_bone < 0: return
	var pose: Dictionary = game.runtime.director.snapshot("dave")
	check(pose.get("asleep") == true,"Director observes fresh Dave sleep without an authored action override")
	check(absf(skeleton.get_bone_pose(root_bone).basis.y.normalized().dot(Vector3.UP)) < 0.2,"fresh source sleep rotates actual Dave root horizontally")
	check(_dave_sleep_marker_count() == 2,"bound source ActorHud reports both asleep z markers")
	var action: Dictionary = game.resolve_interaction()
	check(action.get("kind") == "quest" and action.get("id") == "dave","actual near-service aim resolves Dave E")
	if action.get("kind") != "quest" or action.get("id") != "dave": return
	_key(KEY_E)
	check(game.runtime.s.mode == "dialogue" and game.hud.modal.visible,"real E opens Dave's source dialogue")
	if game.runtime.s.mode != "dialogue" or not game.hud.modal.visible: return
	var player_before: Dictionary = game.runtime.p.duplicate(true)
	var actor_before: Dictionary = dave.duplicate(true)
	var rng_before: int = game.runtime.state.rng_seed
	var origin: Vector3 = game.actors.dave.position
	var pressed: bool = _press_prefix("wake him up.")
	check(pressed,"actual enabled wake Button is pressed")
	if not pressed: return
	check(dave.get("asleep") == false and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"source wake changes the real flag and releases the modal")
	check(game.runtime.p == player_before and game.runtime.state.rng_seed == rng_before,"wake itself changes no player resource HP or RNG")
	var actor_after: Dictionary = dave.duplicate(true)
	actor_before.erase("asleep"); actor_after.erase("asleep")
	check(actor_after == actor_before and game.actors.dave.position == origin,"wake changes no other actor field or source/visual origin")
	stepped = game.runtime.advance(1.0/60.0)
	check(stepped,"real next active step publishes the awake snapshot")
	if not stepped: return
	game._sync_model_nodes(1.0/60.0)
	pose = game.runtime.director.snapshot("dave")
	check(pose.get("asleep") == false and str(pose.get("action","")).is_empty() and pose.get("local_velocity",Vector3.INF).length_squared() < 0.01,"actual awake stationary action-free snapshot reaches the Scene cosmetic path")
	check(skeleton.get_bone_pose(root_bone).basis.y.normalized().dot(Vector3.UP) > 0.95,"actual composed Scene wakes Dave upright instead of reinjecting sleep")
	check(_dave_sleep_marker_count() == 0,"bound source ActorHud removes asleep markers after actual wake")
	var presentation_player: Dictionary = game.runtime.p.duplicate(true)
	var presentation_actor: Dictionary = dave.duplicate(true)
	var presentation_rng: int = game.runtime.state.rng_seed
	for frame: int in range(40):
		game._sync_model_nodes(0.1)
		check(skeleton.get_bone_pose(root_bone).basis.y.normalized().dot(Vector3.UP) > 0.95,"awake root remains upright across full cosmetic wrap: "+str(frame))
	check(game.runtime.p == presentation_player and dave == presentation_actor and game.runtime.state.rng_seed == presentation_rng and game.actors.dave.position == origin,"four seconds of presentation own no resources actor motion or RNG")
	var current_center := Vector2(float(dave.x)+float(dave.w)*0.5,float(dave.y)+float(dave.h)*0.5)
	var current_target: Vector3 = Content.to_world(current_center,service.target.y)
	var current_approach: Vector3 = Content.to_world(current_center,service.approach.y)+Vector3(service.approach.x-service.target.x,0,service.approach.z-service.target.z)
	_place(current_approach)
	direction = current_target-game.camera.global_position
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.camera.rotation = Vector3(game.pitch,0,0)
	await physics_frame
	action = game.resolve_interaction()
	check(action.get("kind") == "quest" and action.get("id") == "dave","awake Dave remains the actual E target")
	if action.get("kind") != "quest" or action.get("id") != "dave": return
	_key(KEY_E)
	var awake_text := false
	var wake_option := false
	for child: Node in game.hud.menu_box.get_children():
		if child is Label and child.text == "dave is explaining a theory about pigeons.\nthe theory has 17 parts.": awake_text = true
		if child is Button and child.text.begins_with("wake him up."): wake_option = true
	check(game.runtime.s.mode == "dialogue" and game.hud.modal.visible and awake_text and not wake_option,"real second E shows the awake pigeon conversation without a wake option")
	var left: bool = _press_prefix("leave.")
	check(left and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"actual awake dialogue Leave returns cleanly to play")
	if not left: return
	fresh = game.runtime.fresh()
	check(fresh,"fresh lifecycle resets Dave through source authority")
	if not fresh: return
	game._consume_events(); game._resume(); game._sync_model_nodes(0.0)
	await physics_frame; await physics_frame
	dave = game.runtime.combat.actor("dave")
	check(not dave.is_empty() and dave.get("asleep") == true,"fresh source Dave sleeps again without a test flag write")
	if dave.is_empty(): return
	_place(service.approach)
	direction = service.target-game.camera.global_position
	game.player.rotation.y = atan2(-direction.x,-direction.z)
	game.pitch = atan2(direction.y,Vector2(direction.x,direction.z).length())
	game.camera.rotation = Vector3(game.pitch,0,0)
	stepped = game.runtime.advance(1.0/60.0)
	check(stepped,"fresh reset produces another real Director snapshot")
	if not stepped: return
	game._sync_model_nodes(1.0/60.0)
	var same_rig: bool = game.actors.has("dave") and game.actors.dave.get_node_or_null("Art") == art and is_instance_valid(skeleton)
	check(same_rig,"fresh Dave reuses the real observed rig rather than a stale test reference")
	if not same_rig: return
	check(absf(skeleton.get_bone_pose(root_bone).basis.y.normalized().dot(Vector3.UP)) < 0.2 and _dave_sleep_marker_count() == 2,"fresh source sleep returns horizontal rig and both z markers")
	game.player.rotation.y = 0; game.pitch = -0.04; game.camera.rotation = Vector3(game.pitch,0,0)
	dave_wake_completed = true

func _test_cooking_controls() -> void:
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game.runtime.fresh(); game._resume()
	var block: Dictionary = game.world.service_points["smoke:block"]
	_place(block.approach); game.camera.rotation = Vector3.ZERO
	game.runtime.p.supplies = 6; game.runtime.p.dirtySupplies = 2
	game.runtime.p.rockedT = 12000; game.runtime.p.shakes = 70
	game.interact()
	var offered: bool = false
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with("cook a batch."):
			offered = true; child.pressed.emit(); break
	check(offered and game.runtime.s.mode == "dialogue","actual Block menu opens cooking owner")
	_key(KEY_1)
	check(game.runtime.s.mode == "cookmini" and game.runtime.cooking.is_active() and not game.hud.modal.visible,"cooking choice releases ordinary menu without cancelling heat")
	var day: float = game.runtime.s.dayTime
	var high: float = game.runtime.p.rockedT
	game._process(0.5)
	check(game.runtime.cooking.snapshot().t == 50 and game.heat_view.panel.visible,"scene clamps one heat frame and displays real needle")
	check(game.runtime.s.dayTime == day and game.runtime.p.rockedT == high,"cooking pauses both world day and high clocks")
	game.runtime.s.hitPause = 80
	game._process(0.05)
	check(game.runtime.cooking.snapshot().t == 50 and game.runtime.s.hitPause == 30,"hit pause consumes frame before heat update")
	game._process(0.05); game._process(0.05)
	check(game.runtime.cooking.snapshot().t == 100,"heat resumes only on next unpaused frame")
	_key(KEY_E); _key(KEY_I); _key(KEY_P)
	check(game.runtime.s.mode == "cookmini" and not game.hud.modal.visible,"heat owns interaction and ledger input")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	game._unhandled_input(click)
	check(game.runtime.cooking.snapshot().phase == "hold","left click locks the real heat record")
	_key(KEY_ENTER)
	check(game.runtime.cooking.snapshot().holdT == 600,"second lock cannot restart hold")
	_key(KEY_ESCAPE)
	check(game.runtime.p.supplies == 5 and game.runtime.p.dirtySupplies == 1 and game.runtime.s.mode == "playing","hold Escape pays one captured packet then returns to play")
	game._process(0.001)
	check(not game.heat_view.panel.visible and not game.hud.modal.visible,"bail leaves no heat or ordinary modal over game")
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game.runtime.p.supplies = 5000; game.runtime.p.dirtySupplies = 0
	game._open_cooking(); _key(KEY_4)
	var heat: Dictionary = game.runtime.s.heat
	heat.progress = heat.sweetCenter
	_key(KEY_SPACE)
	for frame: int in range(12): game._process(0.05)
	check(game.runtime.cooking.is_resolving() and game.runtime.p.supplies == 5000,"large batch reaches bounded resolution without partial charge")
	game._manual_save(); game._request_quit(); game._pause()
	check(game.runtime.s.mode == "cookmini" and game.pending_save.is_empty() and not game.hud.modal.visible and game.quit_requested,"save, native close and pause wait behind accepted batch")
	_key(KEY_ESCAPE)
	check(game.runtime.cooking.is_resolving(),"Escape cannot discard accepted resolution")
	game._process(0.05); game._process(0.05)
	check(not game.runtime.cooking.is_active() and game.runtime.p.supplies == 0 and game.runtime.p.rocks > 0,"bounded settlement pays one complete batch")
	check(game.runtime.s.mode == "paused" and game.hud.modal.visible and not game.heat_view.panel.visible,"deferred pause appears after settlement")
	while game.saving or not game.pending_save.is_empty(): await process_frame
	var saved: Dictionary = await game.store.read_save()
	check(saved.get("player",{}).get("supplies",-1) == 0,"deferred persisted snapshot includes settled cost")
	game.quit_requested = false
	game.runtime.s.smokeT = 1000
	game._process(0.05)
	check(game.runtime.s.smokeT == 950 and game.heat_view.smoke.visible,"smoke presentation decays while paused")
	game._resume()

func _test_companion_controls() -> void:
	game.runtime.fresh(); game._resume()
	check(is_same(game.runtime.heists.puzzle,game.runtime.companions.puzzle) and is_same(game.runtime.lockpick,game.runtime.heists.puzzle),"heists and companions share one puzzle owner")
	var possum: Dictionary = game.world.service_points.possum
	for visit: int in range(5):
		_place(possum.approach,possum.target)
		var action: Dictionary = game.interact()
		check(action.get("kind") == "companion" and action.id == "possum","actual possum uses shared companion domain")
		_key(KEY_1)
	check(game.runtime.s.counters.possumProphecies == 5 and not game.hud.modal.visible,"five real prophecy choices close once and count exactly")
	game.runtime.advance_wall(game.runtime._wall_ms+2200.0)
	game._sync_model_nodes(0.0); game._consume_events()
	check(game.runtime.p.hasPossum and game.actors.has("pet_possum"),"due possum callback adds real authored rig at physical placement")
	var pet: Dictionary = game.runtime.companions._actor("pet_possum")
	if not pet.is_empty():
		var target: Vector3 = Content.body_position(pet)
		_place(target+Vector3(0.8,0,0),target+Vector3(0,1.2,0))
		game._domain_menu("companion",game.runtime.open_companion("pet_possum"))
		_key(KEY_1); game._sync_model_nodes(0.0)
		check(pet.get("departed",false) and not game.actors.pet_possum.visible and not game.runtime.p.hasPossum,"release keeps source record but removes companion visually")
		var reacquire: Dictionary = game.runtime.companions.spawn_pet_possum()
		check(reacquire.get("already_present",false) and not game.runtime.p.hasPossum,"retained released possum cannot be acquired again")
	var dog: Dictionary = game.world.service_points.scrap_dog
	_place(dog.approach,dog.target)
	var action: Dictionary = game.interact()
	check(action.get("kind") == "companion" and action.id == "scrap_dog","chained dog uses actual closest-NPC scan")
	_key(KEY_2)
	check(game.runtime.companions._page == "lock","dog free option starts shared four-pin puzzle")
	var count: int = 0
	for child: Node in game.hud.menu_box.get_children():
		if child is Button: count += 1
	check(count == 5,"dog puzzle contains four pins and source give-up only")
	var solution: Array = game.runtime.lockpick.get("_target").duplicate()
	for pin: int in solution: _key(KEY_1+pin-1)
	game._sync_model_nodes(0.0)
	check(game.runtime.s.quests.scrap_dog.state == "freed" and not game.actors.scrap_dog.visible,"actual four inputs free dog and hide retained original")
	check(game.runtime.restore(game.runtime.snapshot()),"freed dog survives full save restore")
	game._sync_model_nodes(0.0)
	check(not game.actors.scrap_dog.visible,"restored freed dog does not reappear as a corpse")
	game.runtime.s.freedDogT = 1
	game.runtime.advance(0.017); game._sync_model_nodes(0.017); game._consume_events()
	check(game.actors.has("freed_dog_follower") and game.actors.freed_dog_follower.visible,"return timer creates real follower rig through shared Director")
	game.runtime.s.freedDogFollowT = 1
	game.runtime.advance(0.017); game._sync_model_nodes(0.017)
	check(not game.actors.freed_dog_follower.visible,"departing follower disappears without a combat corpse")
	game.runtime.s.freedDogT = 1
	game.runtime.advance(0.017); game._sync_model_nodes(0.017)
	var rows: int = 0
	for body: Dictionary in game.runtime.state.npcs:
		if body.id == "freed_dog_follower": rows += 1
	check(rows == 1 and game.actors.freed_dog_follower.visible,"next return replaces dead keyed row and reuses one visible rig")

func _press_prefix(prefix: String) -> bool:
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and child.text.begins_with(prefix) and not child.disabled:
			child.pressed.emit(); return true
	return false

func _test_office_controls() -> void:
	game.runtime.fresh(); game._resume()
	var door: Dictionary = game.world.service_points.office
	_place(door.approach,door.target)
	var action: Dictionary = game.interact()
	check(action.get("kind") == "office" and not game.runtime.s.office.owned and game.hud.modal.visible,"actual office door opens locked aside without granting ownership")
	_key(KEY_ESCAPE)
	game.runtime.p.cash = 1000; game.runtime.p.copper = 30; game.runtime.p.lifetime.routesCompleted = 3
	var lease: Dictionary = game.world.service_points.lease_guy
	_place(lease.approach,lease.target)
	action = game.interact()
	check(action.get("id") == "lease_guy" and action.get("kind") == "office","actual nearest leasing resident uses Office owner")
	check(_press_prefix("replace the lock."),"real lease choice is enabled by source conditions")
	check(game.runtime.s.office.owned and game.runtime.p.cash == 960 and game.runtime.p.copper == 29,"lease choice pays exact source lock cost once")
	_place(door.approach,door.target); game.interact()
	check(_press_prefix("look at office upgrades."),"office opens upgrades through its consumed token")
	var desk_id: String = ""
	for upgrade: Dictionary in game.runtime.office.upgrades:
		if upgrade.id == "desk": desk_id = str(upgrade.name)
	check(not desk_id.is_empty() and _press_prefix(desk_id+" · "),"real desk purchase enables claims")
	_press_prefix("back to the office.")
	check(_press_prefix("open district claims."),"desk routes to actual claims page")
	var claim_label: String = ""
	for child: Node in game.hud.menu_box.get_children():
		if child is Button and not child.disabled and child.text.to_lower().contains("drainage"):
			claim_label = child.text; child.pressed.emit(); break
	check(not claim_label.is_empty() and game.runtime.s.office.claimJob is Dictionary,"real claim selection captures source survey")
	game._resume()
	var field: Dictionary = game.runtime.office.active_field_target()
	if not field.is_empty():
		var service: Dictionary = game.world.service_points[field.id]
		_place(service.approach,service.target); action = game.interact()
		check(action.get("kind") == "office_field" and game.runtime.s.office.claimJob.stage == "file","aimed physical survey advances exact claim stage")
		_place(door.approach,door.target); game.interact()
		check(_press_prefix("file "),"survey returns to actual office filing option")
		game._resume(); field = game.runtime.office.active_field_target()
		if not field.is_empty():
			service = game.world.service_points[field.id]
			_place(service.approach,service.target); action = game.interact()
			check(action.get("kind") == "office_field" and game.runtime.s.office.claimJob == null and game.runtime.s.districtClaims[field.claim_id],"physical sign installs one claimed district")
		else: check(false,"filing exposes live install target")
	else: check(false,"selected claim exposes live survey target")
	game.runtime.s.office.upgrades.locker = true
	_place(door.approach,door.target); game.interact()
	check(_press_prefix("open the chained locker."),"office locker opens shared Travel menu")
	check(game.runtime.travel._service == "office:chest","locker retains real Travel ownership")
	check(_press_prefix("close the chest."),"locker offers source back navigation")
	check(game.runtime.office._target == "office" and game.hud.modal.visible and game.runtime.s.mode == "dialogue","Travel back revalidates and preserves Office modal")
	game._pause(); game._resume()
	check(game.runtime.office._target.is_empty(),"pause invalidates Office capability")

func _test_world_prop_controls() -> void:
	game.runtime.fresh(); game._resume()
	check(game.runtime.world_props.ready(),"live prop commands share Runtime props and Companion authority")
	var ids: Dictionary = {}
	for index: int in range(game.runtime.state.content.props.size()):
		var prop: Dictionary = game.runtime.props.record("prop:%d" % index)
		if prop.type in ["dumpster","park_bench","pay_phone"] and not ids.has(prop.type): ids[prop.type] = "prop:%d" % index
	var id: String = ids.dumpster
	game.runtime.props.set_dumpster_looted(id,false)
	var service: Dictionary = game.world.service_points[id]
	_place(service.approach,service.target)
	check(game.physics.can_reach_target(id),"actual dumpster approach has source reach and LOS")
	var action: Dictionary = game.interact()
	check(action.get("kind") == "world_props" and game.hud.modal.visible,"actual dumpster opens its source loot menu")
	var count: int = game.runtime.s.counters.get("dumpDives",0)
	_key(KEY_ESCAPE)
	check(not game.runtime.props.record(id).looted and game.runtime.s.counters.get("dumpDives",0) == count,"Escape leaves dumpster unlooted and counter untouched")
	_place(service.approach,service.target); game.interact(); _key(KEY_1)
	check(game.runtime.props.record(id).looted and game.runtime.props.record(id).diveCdT == 90000 and game.runtime.s.counters.dumpDives == count+1,"real numbered choice takes one offer and starts exact source cooldown")
	game._resume()
	id = ids.park_bench; service = game.world.service_points[id]
	_place(service.approach,service.target); action = game.interact()
	check(action.get("kind") == "world_props" and game.runtime.s.get("sittingOnBench",false) and not game.hud.modal.visible,"actual bench toggles source sit without holding a menu")
	game.runtime.p.brain = 40; game.runtime.s.benchSitGainT = 0
	game.runtime.advance(2.01)
	check(game.runtime.s.benchSitT >= 2000 and game.runtime.p.brain >= 41,"live scheduling awards bench brain at two seconds")
	var sit_ms: float = game.runtime.s.benchSitT
	game._pause(); game.runtime.advance(1.0)
	check(game.runtime.s.benchSitT == sit_ms,"paused scene freezes bench timer")
	game._resume(); _place(service.approach,service.target); game.interact()
	check(not game.runtime.s.get("sittingOnBench",false),"second actual bench interaction stands")
	id = ids.pay_phone; service = game.world.service_points[id]
	game.runtime.s.phonePropRingT = 30000; game.runtime.s.publicPhoneAnswered = 0
	_place(service.approach,service.target); action = game.interact()
	check(action.get("kind") == "world_props" and game.runtime.s.phonePropRingT == 0 and game.runtime.s.publicPhoneAnswered == 1,"actual ringing phone commits one source answer")
	game.interact()
	check(game.runtime.s.publicPhoneAnswered == 1,"same physical phone cannot pay a second answer")
	game._resume()

func _test_kingdom_controls() -> void:
	game.runtime.fresh(); game._resume()
	check(game.runtime.kingdom != null and game.runtime.kingdom.ready(),"live Kingdom shares Combat/Campaign/Office/Day owners")
	game.runtime.s.office.owned = true; game.runtime.s.office.upgrades.radio = true
	game.runtime.s.kingdom.stage = "summons"
	var service: Dictionary = game.world.service_points.office
	_place(service.approach,service.target); game.interact()
	check(_press_prefix("open the hostile correspondence."),"actual Office choice opens Kingdom ledger")
	check(game.runtime.kingdom._ledger_open and game.hud.modal.visible,"consumed Office choice becomes real Kingdom capability")
	check(_press_prefix("answer the frequency."),"actual radio choice accepts summons")
	check(game.runtime.s.kingdom.stage == "tarp_marks" and game.runtime.s.mode == "playing","accepted summons exposes corrections and releases modal")
	var clan: Dictionary = game.runtime.kingdom.clans[0]
	for index: int in range(3):
		var id := "kingdom_mark:%s:%d" % [clan.id,index]
		service = game.world.service_points[id]
		_place(service.approach,service.target)
		var action: Dictionary = game.interact()
		check(action.get("kind") == "kingdom_target" and int(game.runtime.s.kingdom.marks)&(1<<index) != 0,"actual aimed correction commits source mark:"+id)
	check(game.runtime.s.kingdom.marks == 7,"all three live corrections reveal court challenge")
	var banner: String = "kingdom_banner:"+str(clan.id)
	service = game.world.service_points[banner]
	_place(service.approach,service.target); game.interact()
	check(game.runtime.s.bossKind == "kingdom" and game.runtime.s.bossActive and game.runtime.s.kingdom.stage == clan.bossStage,"actual banner stages boss and two clerks")
	game._sync_model_nodes(0.0)
	check(game.actors.has(clan.bossId) and game.actors[clan.bossId].visible,"accepted Kingdom boss gets authored visible rig")
	check(game.resolve_interaction().is_empty(),"active court encounter disables ordinary E transactions")
	game.runtime.state.die(); game._consume_events()
	check(not game.runtime.s.bossActive and game.runtime.s.kingdom.stage == clan.marksStage and game.runtime.s.kingdom.marks == 7,"death cleanup preserves entered marks and resets court challenge")
	check(game.runtime.s.kingdomBattle == null and game.runtime.combat.actor(clan.bossId).is_empty(),"death cleanup removes actual boss/adds before save presentation")
	game._resume()

func _test_room_views() -> void:
	game.runtime.fresh(); game._resume()
	game.runtime.memory.discover("park")
	var before: String = JSON.stringify(game.runtime.snapshot())
	var room: Dictionary = game.runtime.memory.room_menu("park")
	check(room.options.size() == 1 and room.options[0].id == "leave" and room.text.contains("the bench does not know you yet."),"known unearned room offers only source leave")
	check(JSON.stringify(game.runtime.snapshot()) == before,"room preview is read-only")
	game._zone_menu("park")
	var count: int = 0
	for node: Node in game.hud.menu_box.get_children():
		if node is Button: count += 1
	check(count == 1 and _press_prefix("leave."),"actual discovery menu cannot offer illegal smoke")
	game.runtime.s.recognition.park.sit = 15; game.runtime.p.rocks = 1; game.runtime.s.dayTime = 0.5
	room = game.runtime.memory.room_menu("park")
	check(room.options.size() == 2 and not room.options[0].enabled and room.options[0].label.contains("philosopher is awake"),"earned day room shows source closed condition")
	game.runtime.s.dayTime = 0.1
	room = game.runtime.memory.room_menu("park")
	check(room.options[0].enabled and room.options[0].label.contains("+18s"),"earned night room offers the real18second action")
	game.runtime.p.rockedT = 1000
	check(not game.runtime.memory.room_menu("park").options[0].enabled,"already high disables conceded smoke option")
	game.runtime.p.rockedT = 0
	game.runtime.state.emit_event("toast",{"text":"the phone has six seconds.","duration_ms":6000}); game._consume_events()
	check(game.hud.receipt_time == 6.0,"actual source toast duration reaches HUD")
	game.runtime.s.flags.introDone = true
	game.runtime.s.quests["view_fixture"] = {"title":"THE SOURCE TITLE","flav":"the source flavor.","done":false}
	game._ledger(false)
	var copy: String = ""
	for node: Node in game.hud.menu_box.get_children():
		if node is Label: copy += node.text
	check(copy.contains("THE SOURCE TITLE") and copy.contains("the source flavor."),"Q uses source title/flav and shows missing available as active")
	game._resume(); game.runtime.s.flags.introDone = false; game._ledger(false)
	copy = ""
	for node: Node in game.hud.menu_box.get_children():
		if node is Label: copy += node.text
	check(not copy.contains("THE SOURCE TITLE"),"intro Q keeps later quests filtered")
	game._resume()

func _test_site_menu() -> void:
	game.runtime.fresh(); game._resume()
	var service: Dictionary = game.world.service_points["copper:abandoned"]
	_place(service.approach)
	game.camera.look_at(game.physics.site_focus("copper:abandoned"))
	var action: Dictionary = game.interact()
	check(action.get("kind") == "heist" and game.runtime.heists.is_active(),"actual aimed facade opens real Heist owner")
	check(game.runtime.s.counters.heistsToday == 1,"scene opens one source copper governor")
	_key(KEY_1)
	check(game.runtime.heists._stage == "take","numbered entry reaches authored copper room")
	_key(KEY_1)
	check(game.runtime.heists._stage == "exit" and game.runtime.p.copper >= 2,"strip action grants real copper and opens getaway")
	var visible_buttons: int = 0
	for child: Node in game.hud.menu_box.get_children():
		if child is Button: visible_buttons += 1
	check(visible_buttons == 2,"getaway shows exactly two source exits without invented leave")
	_key(KEY_ESCAPE)
	check(not game.runtime.heists.is_active() and not game.hud.modal.visible and game.runtime.s.mode == "playing","Escape closes getaway without another charge")
	game.camera.look_at(game.physics.site_focus("copper:abandoned"))
	game.interact()
	_key(KEY_2)
	check(game.runtime.heists._stage == "lock","second entry opens real four-pin puzzle")
	var target: Array = game.runtime.heists.puzzle.get("_target").duplicate()
	for pin: int in target: _key(KEY_1+pin-1)
	check(game.runtime.heists._stage == "take","four actual shortcut presses solve one captured permutation")
	game._pause()
	check(not game.runtime.heists.is_active(),"pause invalidates active heist capability")
	game._resume()

func _load_arrival_race(valid: bool) -> void:
	while game.saving or not game.pending_save.is_empty(): await process_frame
	game.runtime.fresh(); game._resume()
	game.runtime.p.inventory.append({"id":"bus_pass","n":"a bus pass","q":1})
	var pinky: Dictionary = game.world.service_points.pinky
	_place(pinky.approach,pinky.target)
	var menu: Dictionary = game.runtime.open_travel("bus")
	var ride: String = ""
	for choice: Dictionary in menu.get("options",[]):
		if choice.id.begins_with("ride:") and choice.enabled: ride = choice.id; break
	var result: Dictionary = game.runtime.select_travel(menu.get("token"),ride)
	check(result.get("pending",false),"delayed load fixture begins actual bus ride")
	if not result.get("pending",false): return
	game._resume(); game._consume_events()
	var original_store: Node = game.store
	var delayed := DelayedStore.new(); game.add_child(delayed); game.store = delayed
	game.runtime.p.cash = 77
	if valid: delayed.response = game.runtime.snapshot()
	game.runtime.p.cash = 12
	game.call_deferred("_load")
	await delayed.read_started
	game.runtime.advance_wall(game.runtime._wall_ms+380.0); game._consume_events()
	await process_frame
	check(game.loading and not game.pending_save.is_empty() and delayed.writes.is_empty() and delayed.concurrent_writes == 0,"actual arrival save queues while asynchronous read owns storage")
	var arrived: Vector2 = game.runtime.state.player_center()
	delayed.release_read.emit()
	while game.loading or game.saving or not game.pending_save.is_empty(): await process_frame
	if valid:
		check(game.runtime.p.cash == 77 and delayed.writes.is_empty(),"successful restore discards replaced-epoch arrival snapshot")
	else:
		check(game.runtime.p.cash == 12 and game.runtime.state.player_center() == arrived and delayed.writes.size() == 1,"failed read preserves arrival and writes its queued snapshot once")
		check(delayed.writes.size() == 1 and delayed.writes[0].player.cash == 12,"retained save contains current-session arrival progress")
	check(delayed.concurrent_writes == 0,"single adapter never receives overlapping read/write")
	game.store = original_store; delayed.queue_free()
	game._resume()

func _finish() -> void:
	for voice: AudioStreamPlayer in game.sound.players:
		voice.stop(); voice.stream = null
	# The native audio mixer releases its playback references on its own thread.
	await create_timer(0.10).timeout
	game.free(); game = null
	await process_frame
	await process_frame
	if failures.is_empty() and checks >= 80:
		print("3D FULL SCENE GATE: PASS (%d checks;56actors, controls, realcash/Tony/Block, readonlyledger, isolatedsave/load)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D FULL SCENE GATE: FAIL (%d/%dchecks)" % [failures.size(),checks]); quit(1)

func _test_utility_controls() -> void:
	game.runtime.fresh(); game._resume()
	_place(game.world.service_points["smoke:block"].approach); game.camera.rotation = Vector3.ZERO
	game.runtime.p.inventory.append({"id":"lottery","n":"a lottery ticket","q":1})
	game.interact()
	var labels: Array[String] = []
	for node: Node in game.hud.menu_box.get_children():
		if node is Button: labels.append(node.text)
	check(labels.size() == 6 and labels[0].contains("you have none") and labels[4] == "scratch the lottery ticket.","actual Block renders exact conditional source choices")
	check(_press_prefix("scratch the lottery ticket."),"actual ticket choice is actionable")
	var tickets: int = 0
	for item: Dictionary in game.runtime.p.inventory:
		if item.id == "lottery": tickets += 1
	check(tickets == 0 and game.runtime.s.mode == "playing" and not game.hud.modal.visible,"lottery consumes ticket and releases the actual modal")
	game.runtime.p.brain = 60; game.runtime.s.tweakerT = 0; game.runtime.s.tweakerCdT = 0
	_key(KEY_F)
	check(game.squint_held and game.runtime.s.tweakerT == 3000 and game.runtime.p.brain == 55,"F activates source vision once for5brain")
	game._process(0.01)
	check(game.runtime.s.tweakerT == 2990 and game.runtime.s.tweakerCdT == 5990,"heldF shares admitted source world clock")
	var release := InputEventKey.new(); release.physical_keycode = KEY_F; release.pressed = false
	game._unhandled_input(release); game._process(0.01)
	check(not game.squint_held and game.runtime.s.tweakerT == 0,"F release ends vision on the next actual world step")
	game.runtime.s.tweakerCdT = 0; _key(KEY_F); game._ledger(true)
	check(not game.squint_held and not game.runtime.s.keys.has("f"),"modal clears held vision input without a stuck key")
	game._resume()
	var zone: Dictionary = {}
	for row: Dictionary in game.runtime.state.content.world.zones:
		if row.id == "market": zone = row; break
	var placed: bool = false
	for y: int in range(int(zone.y)+30,int(zone.y+zone.h)-30,35):
		for x: int in range(int(zone.x)+30,int(zone.x+zone.w)-30,35):
			_place(Content.to_world(Vector2(x,y),game.Adapter.FEET))
			game.camera.rotation = Vector3(-1.2,0,0)
			if game.resolve_interaction().get("kind") == "utilities": placed = true; break
		if placed: break
	check(placed,"real market has a physically clear zone action away from NPCs")
	if placed:
		game.interact(); labels.clear()
		for node: Node in game.hud.menu_box.get_children():
			if node is Button: labels.append(node.text)
		check(labels == ["ask for change. (chance of $1-5)","perform a song you don't know.","do a card trick you don't know.","leave."],"actual market renders all three source actions and leave")
		check(_press_prefix("perform a song") and game.runtime.s.mode == "playing","market action commits and releases menu")
	game._resume(); game.runtime.drain_events(); game.runtime.s.autoSaveT = 45000
	game.runtime.advance(0.001)
	var saves: int = 0
	for event: Dictionary in game.runtime.drain_events():
		if event.kind == "save_requested": saves += 1
	check(saves == 1 and game.runtime.s.autoSaveT == 0,"actual Runtime tail emits strict45second autosave once")

func _test_interactive_controls() -> void:
	game.runtime.fresh(); game._resume()
	check(game.world.dynamic_interactive and game.runtime.interactive_props.ready() and game.prop_view != null,"production uses one live interactive owner and original-mesh view")
	var chosen: String = ""
	for index: int in range(6):
		var id := "interactive:%d" % index
		if not game.world.service_points.has(id): continue
		var service: Dictionary = game.world.service_points[id]
		_place(service.approach,service.target)
		if game.resolve_interaction().get("kind") == "kick_can": chosen = id; break
	check(not chosen.is_empty(),"real aim and physics expose kickable source can")
	if not chosen.is_empty():
		game.interact()
		var row: Dictionary = game.runtime.props.interactive_record(chosen)
		check(row.cdT == 60000 and row.tipT == 200 and game.runtime.s.mode == "playing","actualE commits can once without menu")
		check(game.prop_view.slot(chosen).get_node("Art").scale.x > 1,"committed can pulse is immediately visible")
		var seed: int = game.runtime.state.rng_seed
		game.interact()
		check(game.runtime.state.rng_seed == seed and row.cdT == 60000,"empty canE emits receipt without another reward or cooldown")
		game._process(0.01)
		check(row.cdT == 59990 and row.tipT == 190,"source can clocks advance in actual controller")
	var bottle: String = ""
	for index: int in range(6,14):
		var id := "interactive:%d" % index
		if game.world.service_points.has(id): bottle = id; break
	check(not bottle.is_empty(),"fresh source bottles have actual live placement")
	if not bottle.is_empty():
		var service: Dictionary = game.world.service_points[bottle]
		_place(service.approach,service.target)
		game.runtime.p.attackCd = 0; game.runtime.p.weapon = "pipe"
		var forward: Vector3 = -game.camera.global_basis.z
		var result: Dictionary = game.runtime.attack(Vector2(forward.x,forward.z)); game._consume_events()
		check(result.ok and game.runtime.props.interactive_record(bottle).broken,"actual accepted swing breaks physically aimed bottle")
		check(game.prop_view.collider(bottle).collision_layer == 0 and not game.world.service_points.has(bottle),"broken bottle immediately leaves physics and interaction before next step")
	game.runtime.fresh(); game._resume()
	check(game.runtime.interactive_props.ready() and game.prop_view.sync(game.runtime.interactive_props.render_records()),"fresh epoch rebinds same original mesh pool")
