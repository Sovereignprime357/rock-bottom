extends Node3D
## Production composition under development. All gameplay is owned by FullRuntime.
const Runtime = preload("res://scripts/full_runtime.gd")
const World = preload("res://scripts/full_neighborhood.gd")
const Adapter = preload("res://scripts/world_adapter.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Roster = preload("res://scripts/character_roster.gd")
const ActorPose = preload("res://scripts/actor_animation.gd")
const Hands = preload("res://scripts/first_person_rig.gd")
const Hud = preload("res://scripts/full_hud.gd")
const Store = preload("res://scripts/save_store.gd")
const Synth = preload("res://scripts/synth.gd")
const FULL_KEY := "rockbottom_3d_full_v2"
var runtime: RefCounted
var physics: RefCounted
var world: Node3D
var player: Node3D
var camera: Camera3D
var hands: Node3D
var hud: CanvasLayer
var store: Node
var sound: Node
var actors: Dictionary = {}
var finds: Dictionary = {}
var projectiles: Dictionary = {}
var ready_for_play: bool = false
var loading: bool = false
var menu_generation: int = 0
var pitch: float = -0.04
var view_look_delta := Vector2.ZERO
var capture_acquired: bool = false
var web_controls: bool = OS.has_feature("web")
var pending_save: Dictionary = {}
var saving: bool = false
var render_serial: int = 0
var active_ms: float = 0.0
var missing_visuals: Array[String] = []
var qa_mode: bool = false

func _ready() -> void:
	qa_mode = "--qa-full" in OS.get_cmdline_user_args()
	_register_inputs()
	hud = Hud.new(); add_child(hud)
	hud.menu("ROCK BOTTOM","the block is getting dressed.",[])
	await get_tree().process_frame
	world = World.new(); add_child(world); world.build()
	physics = Adapter.new(world)
	runtime = Runtime.new(physics); physics.bind_state(runtime.state)
	hud.update_communications(runtime.communications.snapshot())
	_make_player()
	store = Store.new(); add_child(store)
	store.save_path = "user://"+FULL_KEY+".json"; store.storage_key = FULL_KEY
	if qa_mode or "--qa-interactive" in OS.get_cmdline_user_args():
		store.save_path = ProjectSettings.globalize_path("res://../.build/3d/full-scene-qa.json")
		store.storage_key = FULL_KEY+"_qa"
	sound = Synth.new(); add_child(sound)
	for actor: Dictionary in runtime.state.npcs:
		if not _make_actor(actor): return
		await get_tree().process_frame
	# Conditional identities are warm before play; a boss/police spawn cannot build
	# its meshes inside an active frame. Only metadata/instances are needed later.
	for visual: String in Roster.supported_visuals():
		if Roster._templates.has(StringName(visual)): continue
		var warm: Node3D = Roster.create(StringName(visual))
		if warm == null: return
		warm.free()
		await get_tree().process_frame
	await get_tree().physics_frame
	if not runtime.enable_actor_simulation():
		push_error("Full scene actor composition failed."); return
	_sync_model_nodes(0.0)
	get_window().focus_exited.connect(_focus_lost)
	ready_for_play = true
	_title()
	print("3D FULL SCENE READY: %d source actors; %d visual templates" % [actors.size(),Roster._templates.size()])

func _register_inputs() -> void:
	for pair: Array in [["forward",KEY_W],["back",KEY_S],["left",KEY_A],["right",KEY_D],["sprint",KEY_SHIFT]]:
		if InputMap.has_action(pair[0]): continue
		InputMap.add_action(pair[0])
		var key := InputEventKey.new(); key.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0],key)

func _make_player() -> void:
	player = Node3D.new(); player.name = "Player"; add_child(player)
	camera = Camera3D.new(); camera.name = "Eyes"; player.add_child(camera)
	camera.position.y = 1.63; camera.fov = 78; camera.near = 0.06; camera.far = 380; camera.current = true
	hands = Hands.create(); camera.add_child(hands)
	physics.register_body("player",player,1.8)
	_sync_player()

func _make_actor(record: Dictionary) -> bool:
	var id: String = str(record.id)
	var visual: StringName = Roster.visual_for_actor(record)
	if visual.is_empty():
		if not missing_visuals.has(id): missing_visuals.append(id); push_error("Missing authored visual: "+id)
		if runtime != null: runtime.set_mode("paused")
		return false
	var body := Node3D.new(); body.name = id; add_child(body)
	var art: Node3D = Roster.create(visual,id.hash())
	if art == null: body.queue_free(); return false
	art.name = "Art"; body.add_child(art); body.set_meta("visual_id",visual)
	body.set_meta("identity_action",Roster.definition(visual).get("action",&""))
	body.set_meta("cosmetic_ms",float(absi(id.hash())%3800))
	actors[id] = body
	physics.register_body(id,body,float(Roster.definition(visual).height))
	return true

func _sync_player() -> void:
	player.position = Content.to_world(runtime.state.player_center(),Adapter.FEET)
	camera.rotation.x = pitch

func _sync_model_nodes(delta: float) -> void:
	_sync_player()
	var present: Dictionary = {}
	for record: Dictionary in runtime.state.npcs:
		var id: String = str(record.id); present[id] = true
		var visual: StringName = Roster.visual_for_actor(record)
		if actors.has(id) and actors[id].get_meta("visual_id") != visual:
			physics.unregister_body(id)
			actors[id].free(); actors.erase(id)
		if not actors.has(id) and not _make_actor(record): continue
		var body: Node3D = actors[id]
		body.position = Content.to_world(Vector2(record.x+record.w*0.5,record.y+record.h*0.5),Adapter.FEET)
		var pose: Dictionary = runtime.director.snapshot(id) if runtime.director != null else {}
		if pose.has("yaw"): body.rotation.y = float(pose.yaw)
		if delta > 0.0:
			body.set_meta("cosmetic_ms",fmod(float(body.get_meta("cosmetic_ms"))+delta*1000.0,3800.0))
			if str(pose.get("action","")).is_empty() and not pose.get("dead",false) and not pose.get("asleep",false) and pose.get("local_velocity",Vector3.ZERO).length_squared() < 0.01:
				pose.action = body.get_meta("identity_action",&"")
				pose.action_phase = float(body.get_meta("cosmetic_ms"))/3800.0
				pose.ambient_action = true
			var distance: float = player.position.distance_squared_to(body.position)
			ActorPose.tick(body.get_node("Art"),delta,pose,0 if distance < 144.0 else (1 if distance < 1600.0 else 2))
	for id: String in actors.keys():
		if not present.has(id):
			physics.unregister_body(id); actors[id].queue_free(); actors.erase(id)
	_sync_finds()
	_sync_projectiles()

func _simple_mesh(color: String, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = Color(color); material.roughness = 0.92
	node.material_override = material; add_child(node)
	return node

func _sync_finds() -> void:
	var present: Dictionary = {}
	for pile: Dictionary in runtime.state.cash_piles:
		var id: String = str(pile.id); present[id] = true
		if not finds.has(id): finds[id] = _simple_mesh("9b9e67",Vector3(0.25,0.025,0.13))
		finds[id].position = Content.to_world(Vector2(pile.x,pile.y),0.10)
		finds[id].visible = not pile.get("collected",false)
	for id: String in finds.keys():
		if not present.has(id) and id != "quest:crown": finds[id].queue_free(); finds.erase(id)
	var crown: Variant = runtime.s.get("crownPickup")
	if crown is Dictionary and not crown.get("collected",true):
		if not finds.has("quest:crown"):
			var art := Node3D.new(); add_child(art); finds["quest:crown"] = art
			for index: int in range(8):
				var segment: MeshInstance3D = _simple_mesh("a99b54",Vector3(0.09,0.07 if index%2 else 0.12,0.035))
				remove_child(segment); art.add_child(segment)
				var angle: float = float(index)*TAU/8.0
				segment.position = Vector3(sin(angle)*0.10,0.0,cos(angle)*0.10); segment.rotation.y = angle
		finds["quest:crown"].position = Content.to_world(Vector2(crown.x,crown.y),0.13)
	elif finds.has("quest:crown"):
		finds["quest:crown"].queue_free(); finds.erase("quest:crown")

func _sync_projectiles() -> void:
	var present: Dictionary = {}
	for index: int in range(runtime.state.projectiles.size()):
		var record: Dictionary = runtime.state.projectiles[index]
		var id: String = str(index); present[id] = true
		if not projectiles.has(id): projectiles[id] = _simple_mesh("7a8b56",Vector3(0.12,0.28,0.12))
		projectiles[id].position = Content.to_world(Vector2(record.x,record.y),1.0)
	for id: String in projectiles.keys():
		if not present.has(id): projectiles[id].queue_free(); projectiles.erase(id)

func _process(delta: float) -> void:
	if not ready_for_play: return
	render_serial += 1
	runtime.advance_wall(float(Time.get_ticks_msec()))
	_sync_mouse_capture(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	var active: bool = runtime.s.mode == "playing" and not loading
	if active:
		active_ms += minf(delta,0.1)*1000.0
		physics.begin_navigation_frame(render_serial,active_ms)
		var start: Vector3 = player.position
		var motion := Input.get_vector("left","right","forward","back")
		var direction: Vector3 = player.basis*Vector3(motion.x,0,motion.y)
		var sprint: bool = Input.is_action_pressed("sprint") and motion.length_squared() > 0.0
		runtime.advance(minf(delta,0.1),{"input_vector":Vector2(direction.x,direction.z),"sprinting":sprint,"monotonic_ms":Time.get_ticks_msec()})
		var pose_delta: float = runtime.last_advanced_ms/1000.0
		_sync_model_nodes(pose_delta)
		var local_velocity: Vector3 = player.basis.inverse()*(player.position-start)/maxf(delta,0.001)
		hands.tick(pose_delta,local_velocity,sprint,runtime.p.rockedT > 0,runtime.p.crashT > 0,runtime.p.shakes,view_look_delta)
		view_look_delta = Vector2.ZERO
	else: _sync_model_nodes(0.0)
	world.set_day_time(float(runtime.s.dayTime)*240.0)
	hud.update_runtime(runtime)
	_consume_events()
	if runtime.s.mode == "ending":
		for child: Node in hud.menu_box.get_children():
			if child is Button: child.disabled = saving or not pending_save.is_empty()
	var interaction: Dictionary = resolve_interaction()
	hud.prompt.text = str(interaction.get("prompt","")) if runtime.s.mode == "playing" else ""

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_play or loading: return
	if event is InputEventKey and event.pressed and not event.echo:
		sound.ready_for_sound = true
		if runtime.s.mode == "dialogue" and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			hud.activate_choice(int(event.physical_keycode)-int(KEY_1))
			get_viewport().set_input_as_handled(); return
		if event.physical_keycode == KEY_M: sound.muted = not sound.muted
		if event.physical_keycode == KEY_ESCAPE:
			if runtime.s.mode == "playing" or (web_controls and runtime.s.mode == "dialogue"): _pause()
			elif not web_controls and runtime.s.mode not in ["title","ending"]: _resume()
			get_viewport().set_input_as_handled(); return
		if runtime.s.mode == "playing":
			if event.physical_keycode == KEY_E: interact()
			elif event.physical_keycode == KEY_I: _ledger(true)
			elif event.physical_keycode == KEY_Q: _ledger(false)
			elif event.physical_keycode == KEY_P:
				runtime.communications.toggle_feed(); _consume_events()
	if runtime.s.mode != "playing": return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and hud.feed_panel.visible:
		hud.scroll_feed(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or (web_controls and event.button_mask & MOUSE_BUTTON_MASK_RIGHT)):
		var step: Vector2 = event.relative*-0.0022
		view_look_delta += step; player.rotate_y(step.x)
		pitch = clampf(pitch+step.y,-1.25,1.25); camera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		sound.ready_for_sound = true
		if not web_controls and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			var forward: Vector3 = -camera.global_basis.z
			runtime.attack(Vector2(forward.x,forward.z)); _consume_events()

func _sync_mouse_capture(captured: bool) -> void:
	hud.look_hint.visible = web_controls and runtime.s.mode == "playing" and not captured
	if not web_controls: return
	if runtime.s.mode != "playing":
		capture_acquired = false
		if captured: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif captured: capture_acquired = true
	elif capture_acquired: _pause()

func _focus_lost() -> void:
	if ready_for_play and not qa_mode and runtime.s.mode == "playing": _pause()

func _aimed(point: Vector3) -> bool:
	var offset: Vector3 = point-camera.global_position
	return offset.length_squared() < 0.0001 or (-camera.global_basis.z).dot(offset.normalized()) > 0.58

func resolve_interaction() -> Dictionary:
	if runtime == null or runtime.s.mode != "playing" or runtime.s.get("bossKind","") == "kingdom": return {}
	for kind: String in ["mom","scrap"]:
		var id: String = "hideout:"+kind
		if runtime.s.flags.get(kind+"HideoutOwned",false) and physics.can_reach_target(id) and _aimed(world.service_points[id].target):
			return {"kind":"travel","id":id,"prompt":"E  /  go inside."}
	var stop: Dictionary = runtime.progression.current_stop()
	if not stop.is_empty():
		var id: String = "route:"+str(stop.id)
		if physics.can_reach_target(id) and _aimed(world.service_points[id].target): return {"kind":"route","id":id,"prompt":"E  /  stamp the route."}
	var nearest: Dictionary = {}; var distance: float = 3600.0
	for actor: Dictionary in runtime.state.npcs:
		if actor.get("dead",false): continue
		var id: String = str(actor.id)
		var domain: String = "vendor" if id in ["tony","pete","yuri"] else ("resident" if runtime.residents.supports(id) else ("travel" if id in ["pinky","biggu"] else ""))
		if runtime.quests.supports(id): domain = "quest"
		if runtime.street.supports(id): domain = "street"
		if domain.is_empty(): continue
		var center := Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5)
		var square: float = runtime.state.player_center().distance_squared_to(center)
		if square < distance and physics.can_reach_target(id) and _aimed(Content.to_world(center,1.2)):
			nearest = {"kind":domain,"id":id,"prompt":"E  /  "+str(actor.get("name",id)).to_lower()}; distance = square
	if not nearest.is_empty(): return nearest
	for pile: Dictionary in runtime.state.cash_piles:
		if not pile.get("collected",false) and physics.can_reach_target("cash:"+str(pile.id)) and _aimed(Content.to_world(Vector2(pile.x,pile.y),0.14)):
			return {"kind":"cash","id":str(pile.id),"prompt":"E  /  pick it up."}
	var venue: String = "block" if runtime.memory._zone_contains("block",runtime.state.player_center()) else runtime.memory.venue_at(runtime.state.player_center())
	if venue == "block" or (not venue.is_empty() and (runtime.memory.unlocked(venue) or runtime.memory.discovered(venue))):
		if physics.can_use_zone(venue): return {"kind":"smoke","id":venue,"prompt":"E  /  "+("the crate." if venue == "block" else runtime.memory.action_hint(runtime.state.player_center()))}
	if runtime.p.hitters > 0 or runtime.p.copper >= 2: return {"kind":"pocket","id":"pocket","prompt":"E  /  check the pocket."}
	return {}

func interact() -> Dictionary:
	var action: Dictionary = resolve_interaction()
	match action.get("kind",""):
		"vendor": _domain_menu("vendor",runtime.open_vendor(action.id))
		"resident": _domain_menu("resident",runtime.open_resident(action.id))
		"quest": _domain_menu("quest",runtime.open_quest(action.id))
		"street": _domain_menu("street",runtime.open_street(action.id))
		"travel": _domain_menu("travel",runtime.open_travel(action.id))
		"route": runtime.stamp_route()
		"cash": runtime.collect_cash(action.id)
		"smoke": _zone_menu(action.id)
		"pocket": _pocket_menu()
	_consume_events()
	return action

func _option(label: String, callback: Callable, disabled: bool = false) -> Dictionary:
	var serial: int = menu_generation
	return {"label":label,"disabled":disabled,"action":func():
		if serial == menu_generation and not loading: callback.call()}

func _begin_menu() -> void:
	menu_generation += 1; capture_acquired = false; view_look_delta = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _domain_menu(domain: String, result: Dictionary) -> void:
	domain = str(result.get("domain",domain))
	if not result.get("ok",false):
		if result.has("text"): hud.show_receipt(result.text)
		return
	if result.get("closed",false) or not result.has("token"):
		_resume(); return
	_begin_menu()
	var options: Array = []
	var has_leave: bool = false
	for choice: Dictionary in result.options:
		has_leave = has_leave or choice.id == "leave"
		options.append(_option(choice.label,_choose.bind(domain,result.token,str(choice.id)),not choice.get("enabled",true)))
	if not has_leave and domain != "activities": options.append(_option("leave.",_resume))
	hud.menu(str(result.get("title","")),str(result.get("text","")),options)

func _choose(domain: String, token: Variant, action: String) -> void:
	var result: Dictionary
	match domain:
		"vendor": result = runtime.select_vendor(token,action)
		"resident": result = runtime.select_resident(token,action)
		"quest": result = runtime.select_quest(token,action)
		"street": result = runtime.select_street(token,action)
		"activities": result = runtime.select_activity(token,action)
		_: result = runtime.select_travel(token,action)
	_consume_events()
	if result.get("ok",false) and result.has("token"): _domain_menu(domain,result)
	else: _resume()

func _zone_menu(venue: String) -> void:
	runtime.set_mode("dialogue"); _begin_menu()
	var text: String = "the crate has seen everything."
	if venue != "block": text = runtime.memory.ledger_line(venue)
	var options: Array = [_option("smoke a rock.",_smoke.bind(venue))]
	if venue == "block" and runtime.s.flags.get("hasStripePackage",false): options.append(_option("open stripe's package.",_open_package))
	options.append(_option("leave.",_resume))
	hud.menu("THE BLOCK" if venue == "block" else venue.replace("_"," ").to_upper(),text,options)

func _open_package() -> void:
	_domain_menu("quest",runtime.open_package()); _consume_events()

func _smoke(venue: String) -> void:
	runtime.smoke(venue); _resume(); _consume_events()

func _pocket_menu() -> void:
	runtime.set_mode("dialogue"); _begin_menu()
	var options: Array = []
	if runtime.p.hitters > 0: options.append(_option("use the emergency hitter.",_hitter.bind(false)))
	if runtime.p.copper >= 2: options.append(_option("make an emergency hitter. (2 pure copper.)",_hitter.bind(true)))
	options.append(_option("leave.",_resume)); hud.menu("THE POCKET","it contains business.",options)

func _hitter(craft: bool) -> void:
	if craft: runtime.craft_hitter()
	else: runtime.use_hitter()
	_resume(); _consume_events()

func _ledger(inventory: bool) -> void:
	runtime.set_mode("dialogue"); _begin_menu()
	var lines: Array[String] = []
	if inventory: lines.append(hud.inventory_copy(runtime))
	else:
		for id: String in runtime.s.quests:
			var quest: Dictionary = runtime.s.quests[id]
			if quest.get("available",false) or quest.get("done",false): lines.append(("✓ " if quest.get("done",false) else "· ")+str(quest.get("name",id))+"\n"+str(quest.get("desc","")))
		for hustle: Dictionary in runtime.s.hustles: lines.append(("✓ " if hustle.get("done",false) else "· ")+str(hustle.get("desc","")))
		var stop: Dictionary = runtime.progression.current_stop()
		if not stop.is_empty(): lines.append("\nnext stamp: "+str(stop.get("name",stop.id)))
	hud.menu("POCKETS" if inventory else "THE LEDGER","\n\n".join(lines),[_option("leave.",_resume)])

func _title() -> void:
	runtime.set_mode("title"); _begin_menu()
	hud.menu("ROCK BOTTOM","the same block.\nthe same business.",[_option("wake up.",_new_game),_option("remember.",_load)],true)

func _new_game() -> void:
	if loading or saving or not pending_save.is_empty(): return
	if not runtime.fresh(): return
	active_ms = 0.0; _reset_presentation(); _sync_model_nodes(0.0); _resume(); _consume_events()

func _reset_presentation() -> void:
	hands.reset(); view_look_delta = Vector2.ZERO; pitch = -0.04; player.rotation = Vector3.ZERO
	if physics.has_method(&"reset_navigation"): physics.call(&"reset_navigation")
	for body: Node3D in actors.values(): ActorPose.reset(body.get_node("Art"))

func _pause() -> void:
	runtime.set_mode("paused"); _begin_menu()
	hud.menu("STILL HERE","the block is on hold.",[_option("continue.",_resume),_option("remember this.",_manual_save),_option("remember before.",_load),_option("back to the crate.",_title)])

func _resume() -> void:
	if loading: return
	if runtime.s.mode == "ending" and (saving or not pending_save.is_empty()): return
	menu_generation += 1; runtime.close_dialogue(); runtime.set_mode("playing")
	hud.close_menu(); view_look_delta = Vector2.ZERO; sound.ready_for_sound = true
	capture_acquired = false
	if not qa_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _manual_save() -> void:
	_request_save(runtime.snapshot())

func _request_save(snapshot: Dictionary) -> void:
	pending_save = snapshot.duplicate(true)
	if not saving and not loading: call_deferred("_flush_saves")

func _flush_saves() -> void:
	if saving or loading: return
	saving = true
	while not pending_save.is_empty():
		var snapshot: Dictionary = pending_save; pending_save = {}
		if not await store.write_save(snapshot): hud.show_receipt(store.last_error)
	saving = false

func _load() -> void:
	if loading or saving or not pending_save.is_empty(): return
	loading = true; _begin_menu()
	hud.menu("REMEMBERING","the drawer is open.",[])
	var data: Dictionary = await store.read_save()
	if data.is_empty() and store.last_error.is_empty() and not qa_mode:
		var previous_path: String = store.save_path; var previous_key: String = store.storage_key
		store.save_path = Store.SAVE_PATH; store.storage_key = "rockbottom_3d_slice_v1"
		data = await store.read_save()
		store.save_path = previous_path; store.storage_key = previous_key
	var accepted: bool = false
	if not data.is_empty():
		var candidate: RefCounted = Runtime.State.new()
		var decoded: Dictionary = candidate.restore(data)
		if decoded.get("ok",false):
			var body: Dictionary = candidate.p.duplicate(); body.id = "player"
			var clear: Variant = physics.clear_placement(body)
			if clear is Vector2:
				var envelope: Dictionary = candidate.snapshot(); envelope.player.x = clear.x; envelope.player.y = clear.y
				accepted = runtime.restore(envelope)
	# Wall callbacks may request saves while Web's read awaits IndexedDB. Only a
	# successful epoch replacement discards those old-session snapshots.
	if accepted: pending_save = {}
	loading = false
	if not pending_save.is_empty() and not saving: call_deferred("_flush_saves")
	if accepted: active_ms = 0.0; _reset_presentation(); _sync_model_nodes(0.0)
	runtime.set_mode("paused"); _begin_menu()
	hud.menu("REMEMBERED" if accepted else "THE DRAWER","the file remembers.\nthe block continues." if accepted else (store.last_error if not store.last_error.is_empty() else "nothing legible in there."),[_option("continue.",_resume)])

func _consume_events() -> void:
	for event: Dictionary in runtime.drain_events():
		var payload: Dictionary = event.payload
		match event.kind:
			"communications_changed": hud.update_communications(runtime.communications.snapshot())
			"dialogue_requested": _domain_menu(str(payload.domain),payload.menu)
			"toast": hud.show_receipt(str(payload.get("text","")))
			"sound","audio": sound.play_sound("high" if payload.get("id") == "rockUp" else str(payload.get("id","")))
			"gesture": hands.acknowledge(StringName(payload.get("action","interact")))
			"player_attack": hands.acknowledge(&"punch",true,payload.get("connected",false))
			"placement_reset","death","arrest": _reset_presentation(); _sync_player()
			"actor_died": physics.invalidate_navigation_actor(str(payload.get("actor_id","")))
			"save_requested": _request_save(payload.get("snapshot",runtime.snapshot()))
			"ending_requested":
				runtime.set_mode("ending"); _begin_menu()
				hud.menu(str(payload.get("title","CRACK LORD SUPREME")),str(payload.get("text","the corner is yours.\nyou get tuesdays and thursdays.")),[_option("return to the block.",_resume)],true)
