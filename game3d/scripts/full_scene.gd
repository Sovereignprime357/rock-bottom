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
const Startup = preload("res://scripts/startup_presentation.gd")
const InteractiveView = preload("res://scripts/interactive_prop_view.gd")
const CookingView = preload("res://scripts/cooking_presentation.gd")
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
var ledger_key: int = 0
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
var startup_report: Dictionary = {}
var prop_view: Node3D
var heat_view: CanvasLayer
var pending_load: bool = false
var quit_requested: bool = false
var save_failed: bool = false
var squint_held: bool = false
var _hand_context: Dictionary = {}

func _ready() -> void:
	qa_mode = "--qa-full" in OS.get_cmdline_user_args()
	_register_inputs()
	var boot_started: int = Time.get_ticks_usec()
	var startup := Startup.new(); add_child(startup)
	startup.show_stage("the block.",0,1)
	hud = Hud.new(); add_child(hud)
	heat_view = CookingView.new(); add_child(heat_view)
	if not qa_mode: get_tree().auto_accept_quit = false
	await get_tree().process_frame
	world = World.new(); world.dynamic_interactive = true; add_child(world); world.build()
	startup.show_stage("the block.",1,1)
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
	var visuals: Array = Roster.supported_visuals()
	startup.show_stage("the neighbors.",0,visuals.size())
	for index: int in range(visuals.size()):
		await get_tree().process_frame
		if not Roster.prepare(StringName(visuals[index])): return
		startup.show_stage("the neighbors.",index+1,visuals.size())
	var placed: int = 0
	startup.show_stage("everybody has a place.",0,runtime.state.npcs.size())
	for actor: Dictionary in runtime.state.npcs:
		if not _make_actor(actor): return
		placed += 1
		startup.show_stage("everybody has a place.",placed,runtime.state.npcs.size())
		await get_tree().process_frame
	# Resources are prepared once; unseen identities never need temporary rigs.
	await get_tree().physics_frame
	if not runtime.enable_actor_simulation():
		push_error("Full scene actor composition failed."); return
	hud.bind_guidance(runtime.guidance)
	if not runtime.enable_interactive_props():
		push_error("Full scene interactive prop composition failed."); return
	prop_view = InteractiveView.new(); add_child(prop_view)
	if not prop_view.bind(world,physics,runtime.interactive_props) or not physics.sync_interactive_props():
		push_error("Full scene interactive prop presentation failed."); return
	_sync_model_nodes(0.0)
	get_window().focus_exited.connect(_focus_lost)
	ready_for_play = true
	_title()
	startup.finish()
	startup_report = {"elapsed_usec":Time.get_ticks_usec()-boot_started,"stages":startup.stage_timings(),"resources":Roster.preparation_stats()}
	print("3D FULL STARTUP: ",JSON.stringify(startup_report))
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
	var body := Node3D.new(); body.name = id
	body.position = Content.body_position(record,Adapter.FEET)
	add_child(body)
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
		body.visible = not record.get("departed",false) and runtime.days.actor_visible(record)
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
		finds[id].visible = runtime.utilities.cash_visible(pile)
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

func _sync_hand_context() -> void:
	if hands == null or runtime == null: return
	var context := {"weapon":str(runtime.p.weapon),"seated":bool(runtime.s.get("sittingOnBench",false)),"visible":runtime.s.mode == "playing" and not loading,"walk_speed":5.5}
	if context != _hand_context and hands.set_context(context): _hand_context = context

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
		runtime.advance(minf(delta,0.1),{"input_vector":Vector2(direction.x,direction.z),"sprinting":sprint,"squint_held":squint_held,"monotonic_ms":Time.get_ticks_msec()})
		var pose_delta: float = runtime.last_advanced_ms/1000.0
		_sync_model_nodes(pose_delta)
		var local_velocity: Vector3 = player.basis.inverse()*(player.position-start)/maxf(delta,0.001)
		_sync_hand_context()
		hands.tick(pose_delta,local_velocity,sprint,runtime.p.rockedT > 0,runtime.p.crashT > 0,runtime.p.shakes,view_look_delta)
		view_look_delta = Vector2.ZERO
	else:
		if runtime.s.mode == "cookmini" and not loading: runtime.advance(minf(delta,0.05))
		_sync_model_nodes(0.0)
	runtime.advance_presentation(delta)
	heat_view.update(runtime.cooking.snapshot() if runtime.s.mode == "cookmini" else {},runtime.p,float(runtime.s.get("smokeT",0)),delta)
	world.set_day_time(float(runtime.s.dayTime)*240.0)
	hud.set_view_heading(player.rotation.y)
	hud.update_runtime(runtime)
	_consume_events()
	if pending_load and not runtime.cooking.is_resolving() and not loading and not saving and pending_save.is_empty():
		pending_load = false; _load()
	if quit_requested and not runtime.cooking.is_resolving() and not loading and not saving and pending_save.is_empty():
		if save_failed: quit_requested = false
		elif not qa_mode: get_tree().quit()
	if runtime.s.mode == "ending":
		for child: Node in hud.menu_box.get_children():
			if child is Button: child.disabled = saving or not pending_save.is_empty()
	var interaction: Dictionary = resolve_interaction()
	hud.prompt.text = str(interaction.get("prompt","")) if runtime.s.mode == "playing" else ""

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_play or loading: return
	if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_F:
		squint_held = false; runtime.utilities.release_squint()
	if runtime.s.mode == "cookmini":
		if event is InputEventKey and event.pressed and not event.echo:
			sound.ready_for_sound = true
			if event.physical_keycode in [KEY_SPACE,KEY_1,KEY_ENTER,KEY_KP_ENTER]: runtime.lock_cooking()
			elif event.physical_keycode == KEY_ESCAPE:
				if runtime.bail_cooking().get("ok",false): _resume()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			sound.ready_for_sound = true; runtime.lock_cooking()
		_consume_events(); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo:
		sound.ready_for_sound = true
		if runtime.s.mode == "dialogue" and ledger_key != 0 and event.physical_keycode in [ledger_key,KEY_ESCAPE]:
			_resume(); get_viewport().set_input_as_handled(); return
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
			elif event.physical_keycode == KEY_F:
				squint_held = true; runtime.press_squint(); _consume_events()
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
	if runtime == null or runtime.s.mode != "playing" or runtime.p.stunT > 0 or runtime.s.get("bossKind","") == "kingdom": return {}
	if physics.can_reach_target("office") and _aimed(world.service_points.office.target):
		return {"kind":"office","id":"office","prompt":"E  /  the office."}
	for kind: String in ["mom","scrap"]:
		var id: String = "hideout:"+kind
		if runtime.s.flags.get(kind+"HideoutOwned",false) and physics.can_reach_target(id) and _aimed(world.service_points[id].target):
			return {"kind":"travel","id":id,"prompt":"E  /  go inside."}
	if runtime.kingdom != null:
		for door: Dictionary in runtime.kingdom.doors:
			var id: String = "kingdom:"+str(door.id)
			if physics.can_reach_target(id) and _aimed(world.service_points[id].target):
				return {"kind":"kingdom_door","id":id,"prompt":"E  /  knock."}
		if runtime.p.stunT <= 0 and not runtime.s.get("bossActive",false) and not runtime.s.get("brutusOlderActive",false):
			for target: Dictionary in runtime.kingdom.active_targets():
				if physics.can_reach_target(target.id) and _aimed(world.service_points[target.id].target):
					return {"kind":"kingdom_target","id":target.id,"prompt":"E  /  "+runtime.kingdom.action_hint()+"."}
	var field: Dictionary = runtime.office.active_field_target()
	if not field.is_empty() and runtime.p.stunT <= 0 and not runtime.s.get("bossActive",false) and not runtime.s.get("brutusOlderActive",false):
		if physics.can_reach_target(field.id) and _aimed(world.service_points[field.id].target):
			return {"kind":"office_field","id":field.id,"prompt":"E  /  "+str(field.task)}
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
		if runtime.days.supports(id): domain = "day"
		if runtime.office.supports(id): domain = "office"
		if runtime.companions.supports(id): domain = "companion"
		if domain.is_empty(): continue
		var center := Vector2(actor.x+actor.w*0.5,actor.y+actor.h*0.5)
		var square: float = runtime.state.player_center().distance_squared_to(center)
		if square < distance and physics.can_reach_target(id) and _aimed(Content.to_world(center,1.2)):
			nearest = {"kind":domain,"id":id,"prompt":"E  /  "+str(actor.get("name",id)).to_lower()}; distance = square
	if not nearest.is_empty(): return nearest
	var site: String = runtime.heists.site_at(runtime.state.player_center())
	if not site.is_empty():
		var target_id: String = ("copper:" if site in runtime.Heists.COPPER_IDS else "breakin:")+site
		if physics.can_use_site(target_id) and _aimed(physics.site_focus(target_id)):
			return {"kind":"heist","id":site,"prompt":"E  /  go inside."}
	for prop_type: String in ["park_bench","trashcan","pay_phone","dumpster"]:
		if prop_type == "trashcan":
			if runtime.interactive_props != null:
				for index: int in range(6):
					var id := "interactive:%d" % index
					if world.service_points.has(id) and physics.can_reach_target(id) and _aimed(world.service_points[id].target):
						return {"kind":"kick_can","id":id,"prompt":"E  /  kick the can."}
			continue
		if prop_type == "pay_phone" and float(runtime.s.get("phonePropRingT",0)) <= 0: continue
		for id: String in runtime.world_props.interaction_ids(prop_type):
			var prop: Dictionary = runtime.props.record(id)
			if prop.get("type") != prop_type or not world.service_points.has(id): continue
			if not physics.can_reach_target(id) or not _aimed(world.service_points[id].target): continue
			var prompt: String = "get in the dumpster." if not prop.get("looted",false) else "look in the empty dumpster."
			if prop_type == "park_bench": prompt = "stand up." if runtime.s.get("sittingOnBench",false) else "sit on the bench."
			elif prop_type == "pay_phone": prompt = "answer the phone."
			return {"kind":"world_props","id":id,"prompt":"E  /  "+prompt}
	for pile: Dictionary in runtime.state.cash_piles:
		if not pile.get("collected",false) and physics.can_reach_target("cash:"+str(pile.id)) and _aimed(Content.to_world(Vector2(pile.x,pile.y),0.14)):
			return {"kind":"cash","id":str(pile.id),"prompt":"E  /  pick it up."}
	var venue: String = "block" if runtime.memory._zone_contains("block",runtime.state.player_center()) else runtime.memory.venue_at(runtime.state.player_center())
	if venue == "block" or (not venue.is_empty() and (runtime.memory.unlocked(venue) or runtime.memory.discovered(venue))):
		if physics.can_use_zone(venue): return {"kind":"smoke","id":venue,"prompt":"E  /  "+("the crate." if venue == "block" else runtime.memory.action_hint(runtime.state.player_center()))}
	if runtime.memory._zone_contains("market",runtime.state.player_center()) and physics.can_use_zone("market"):
		return {"kind":"utilities","id":"market","prompt":"E  /  panhandle."}
	if runtime.p.hitters > 0 or runtime.p.copper >= 2: return {"kind":"pocket","id":"pocket","prompt":"E  /  check the pocket."}
	return {}

func interact() -> Dictionary:
	var action: Dictionary = resolve_interaction()
	match action.get("kind",""):
		"vendor": _domain_menu("vendor",runtime.open_vendor(action.id))
		"resident": _domain_menu("resident",runtime.open_resident(action.id))
		"quest": _domain_menu("quest",runtime.open_quest(action.id))
		"street": _domain_menu("street",runtime.open_street(action.id))
		"heist": _domain_menu("heist",runtime.open_heist(action.id))
		"day": _domain_menu("day",runtime.open_day_actor(action.id))
		"utilities": _domain_menu("utilities",runtime.open_zone(action.id))
		"kick_can": runtime.kick_can(action.id)
		"world_props": _domain_menu("world_props",runtime.open_world_prop(action.id))
		"companion": _domain_menu("companion",runtime.open_companion(action.id))
		"office": _domain_menu("office",runtime.open_office(action.id))
		"office_field": runtime.use_office_field(action.id)
		"kingdom_door": runtime.use_kingdom(action.id,true)
		"kingdom_target": runtime.use_kingdom(action.id)
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
	ledger_key = 0
	squint_held = false; runtime.utilities.release_squint()
	menu_generation += 1; capture_acquired = false; view_look_delta = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _domain_menu(domain: String, result: Dictionary) -> void:
	domain = str(result.get("domain",domain))
	if not result.get("ok",false):
		if result.has("text"): hud.show_receipt(result.text)
		return
	if result.get("started",false) and result.get("mode") == "cookmini":
		_begin_menu(); hud.close_menu(); return
	if result.get("closed",false) or not result.has("token"):
		_resume(); return
	_begin_menu()
	var options: Array = []
	var has_leave: bool = false
	for choice: Dictionary in result.options:
		has_leave = has_leave or choice.id == "leave"
		options.append(_option(choice.label,_choose.bind(domain,result.token,str(choice.id)),not choice.get("enabled",true)))
	if not has_leave and domain not in ["activities","heist","day","cooking","office","companion","travel","kingdom","utilities"]: options.append(_option("leave.",_resume))
	hud.menu(str(result.get("title","")),str(result.get("text","")),options)

func _choose(domain: String, token: Variant, action: String) -> void:
	var result: Dictionary
	match domain:
		"vendor": result = runtime.select_vendor(token,action)
		"resident": result = runtime.select_resident(token,action)
		"quest": result = runtime.select_quest(token,action)
		"street": result = runtime.select_street(token,action)
		"activities": result = runtime.select_activity(token,action)
		"heist": result = runtime.select_heist(token,action)
		"day": result = runtime.select_day_actor(token,action)
		"cooking": result = runtime.select_cooking(token,action)
		"office": result = runtime.select_office(token,action)
		"kingdom": result = runtime.select_kingdom(token,action)
		"utilities": result = runtime.select_utility(token,action)
		"world_props": result = runtime.select_world_prop(token,action)
		"companion": result = runtime.select_companion(token,action)
		_: result = runtime.select_travel(token,action)
	_consume_events()
	if result.get("ok",false) and result.get("navigation") == "office":
		_domain_menu("office",runtime.open_office("office")); return
	if result.get("ok",false) and (result.has("token") or result.get("started",false)): _domain_menu(domain,result)
	else: _resume()

func _zone_menu(venue: String) -> void:
	if venue != "block":
		var room: Dictionary = runtime.memory.room_menu(venue)
		if room.is_empty(): return
		if not runtime.set_mode("dialogue"): return
		_begin_menu()
		var room_options: Array = []
		for choice: Dictionary in room.options:
			room_options.append(_option(choice.label,_smoke.bind(venue) if choice.id == "smoke" else _resume,not choice.enabled))
		hud.menu(room.title,room.text,room_options); return
	_domain_menu("utilities",runtime.open_zone("block")); _consume_events()

func _open_cooking() -> void:
	_domain_menu("cooking",runtime.open_cooking()); _consume_events()

func _sleep_block() -> void:
	runtime.sleep_at_block(); _resume(); _consume_events()

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
	ledger_key = KEY_I if inventory else KEY_Q
	var lines: Array[String] = []
	if inventory: lines.append(hud.inventory_copy(runtime))
	else: lines.append(runtime.guidance.journal_text())
	hud.menu("POCKETS" if inventory else "THE LEDGER","\n\n".join(lines),[_option("leave.",_resume)])

func _title() -> void:
	if not runtime.set_mode("title"): return
	_begin_menu()
	hud.menu("ROCK BOTTOM","the same block.\nthe same business.",[_option("wake up.",_new_game),_option("remember.",_load)],true)

func _new_game() -> void:
	if loading or saving or not pending_save.is_empty(): return
	if not runtime.fresh(): return
	active_ms = 0.0; _reset_presentation(); _sync_model_nodes(0.0); _resume(); _consume_events()

func _reset_presentation() -> void:
	squint_held = false; runtime.utilities.release_squint()
	hands.reset(); _hand_context.clear(); _sync_hand_context(); view_look_delta = Vector2.ZERO; pitch = -0.04; player.rotation = Vector3.ZERO
	if physics.has_method(&"reset_navigation"): physics.call(&"reset_navigation")
	for body: Node3D in actors.values(): ActorPose.reset(body.get_node("Art"))

func _pause() -> void:
	if not runtime.set_mode("paused"): return
	_begin_menu()
	hud.menu("STILL HERE","the block is on hold.",[_option("continue.",_resume),_option("remember this.",_manual_save),_option("remember before.",_load),_option("back to the crate.",_title)])

func _resume() -> void:
	if loading: return
	if runtime.s.mode == "ending" and (saving or not pending_save.is_empty()): return
	if not runtime.set_mode("playing"): return
	menu_generation += 1; runtime.close_dialogue()
	ledger_key = 0
	hud.close_menu(); view_look_delta = Vector2.ZERO; sound.ready_for_sound = true
	capture_acquired = false
	if not qa_mode: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _manual_save() -> void:
	runtime.request_save(); _consume_events()

func _request_save(snapshot: Dictionary) -> void:
	pending_save = snapshot.duplicate(true)
	if not saving and not loading: call_deferred("_flush_saves")

func _flush_saves() -> void:
	if saving or loading: return
	saving = true; save_failed = false
	while not pending_save.is_empty():
		var snapshot: Dictionary = pending_save; pending_save = {}
		if not await store.write_save(snapshot):
			save_failed = true; hud.show_receipt(store.last_error)
	saving = false

func _load() -> void:
	if runtime.cooking.is_resolving(): pending_load = true; return
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
	_sync_hand_context()
	for event: Dictionary in runtime.drain_events():
		var payload: Dictionary = event.payload
		match event.kind:
			"lifecycle_applied":
				if payload.get("ok",false):
					if payload.get("kind") in ["fresh","restore"]:
						active_ms = 0.0; _reset_presentation(); _sync_model_nodes(0.0)
					match runtime.s.mode:
						"paused": _pause()
						"title": _title()
						"playing": _resume()
			"cooking_changed":
				if runtime.s.mode == "playing" and not runtime.cooking.is_active(): _resume()
			"communications_changed": hud.update_communications(runtime.communications.snapshot())
			"site_availability_changed": world.set_site_available(str(payload.id),payload.get("available",false))
			"dialogue_requested": _domain_menu(str(payload.domain),payload.menu)
			"toast": hud.show_receipt(str(payload.get("text","")),float(payload.get("duration_ms",2200)))
			"sound","audio": sound.play_sound("high" if payload.get("id") == "rockUp" else str(payload.get("id","")))
			"gesture": hands.acknowledge(StringName(payload.get("action","interact")))
			"player_attack": hands.acknowledge(&"punch",true,payload.get("connected",false),StringName(payload.get("used_weapon","")))
			"placement_reset","death","arrest": _reset_presentation(); _sync_player()
			"actor_died": physics.invalidate_navigation_actor(str(payload.get("actor_id","")))
			"save_requested": _request_save(payload.get("snapshot",runtime.snapshot()))
			"ending_requested","ending":
				if not runtime.set_mode("ending"): continue
				_begin_menu()
				hud.menu(str(payload.get("title","CRACK LORD SUPREME")),str(payload.get("text","the corner is yours.\nyou get tuesdays and thursdays.")),[_option("return to the block.",_resume)],true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not qa_mode:
		if not ready_for_play: get_tree().quit(); return
		_request_quit()

func _request_quit() -> void:
	quit_requested = true; pending_load = false
	runtime.request_save(); _consume_events()
