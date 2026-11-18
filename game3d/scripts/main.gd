extends Node3D

const Simulation = preload("res://scripts/simulation.gd")
const Neighborhood = preload("res://scripts/neighborhood.gd")
const Art = preload("res://scripts/character_art.gd")
const Hud = preload("res://scripts/hud.gd")
const Store = preload("res://scripts/save_store.gd")
const Synth = preload("res://scripts/synth.gd")

var sim := Simulation.new()
var world: Node3D
var hud: CanvasLayer
var store: Node
var sound: Node
var player: CharacterBody3D
var camera: Camera3D
var hands: Node3D
var anchors: Dictionary
var actors: Dictionary = {}
var actor_positions: Dictionary = {}
var targets: Dictionary = {}
var mode := "title"
var target_id := ""
var pitch := -0.04
var attack_cd := 0.0
var attack_time := 0.0
var clock := 0.0
var enemy_hp := 120.0
var enemy_cooldown := 0.0
var enemy_windup := 0.0
var enemy_hit_ready := false
var enemy_recoil := 0.0
var last_day := 1
var save_pending := false
var loading := false
var spawned := false
var qa_mode := false

func _ready() -> void:
	_register_inputs()
	world = Neighborhood.new()
	add_child(world)
	world.build()
	anchors = world.anchors()
	_make_player()
	_make_people()
	_make_targets()
	hud = Hud.new()
	add_child(hud)
	store = Store.new()
	add_child(store)
	sound = Synth.new()
	add_child(sound)
	sim.fresh()
	get_window().focus_exited.connect(_focus_lost)
	spawned = true
	qa_mode = "--qa-tour" in OS.get_cmdline_user_args()
	_title()
	if qa_mode:
		call_deferred("_qa_tour")
	if "--qa-capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_views")

func _register_inputs() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT}
	for action: String in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)

func _make_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.collision_layer = 8
	player.collision_mask = 3
	add_child(player)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = 0.88
	player.add_child(shape)
	camera = Camera3D.new()
	camera.name = "Eyes"
	camera.position.y = 1.63
	camera.fov = 78
	camera.near = 0.06
	camera.far = 180
	player.add_child(camera)
	camera.current = true
	hands = Art.create_character("player_hands")
	camera.add_child(hands)
	_respawn()

func _make_people() -> void:
	for id in ["tony", "pete", "yuri", "lurch", "possum", "brutus"]:
		var body := CharacterBody3D.new()
		body.name = id
		body.collision_layer = 2
		body.collision_mask = 1
		body.set_meta("interaction_id", id)
		add_child(body)
		var location: Vector3 = anchors.get(id, Vector3(-31, 0, 11))
		if id == "pete": location = Vector3(-18, 0, -12.2)
		body.position = location
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34 if id != "possum" else 0.19
		capsule.height = 1.75 if id not in ["possum", "brutus"] else 0.4
		shape.shape = capsule
		shape.position.y = capsule.height * 0.5
		body.add_child(shape)
		var art: Node3D = Art.create_character(id)
		art.name = "Art"
		body.add_child(art)
		actors[id] = body
		if id == "yuri": body.rotation.y = PI * 0.5
		if id == "lurch": body.rotation.y = -PI * 0.5

func _make_targets() -> void:
	_make_target("block", anchors.block + Vector3(0, 0.75, 0), Vector3(1.25, 1.5, 1.25))
	_make_target("pete", anchors.pete + Vector3(0, 0.22, 0.18), Vector3(2.3, 1.1, 0.3))
	for id in ["dumpster_1", "dumpster_2", "dumpster_3"]:
		_make_target(id, anchors[id] + Vector3(0, 1.12, 0.67), Vector3(1.85, 1.5, 0.45))
	for id in ["cash_1", "cash_2", "cash_3", "copper_1"]:
		_make_target(id, anchors[id] + Vector3(0, 0.22, 0), Vector3(0.8, 0.6, 0.8))
		var art := Node3D.new()
		art.name = "Find"
		targets[id].add_child(art)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b8a56b") if id.begins_with("cash") else Color("b16638")
		material.roughness = 0.8
		for part in range(4):
			var mesh := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.06 if id.begins_with("cash") else 0.055
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = 0.018 if id.begins_with("cash") else 0.65
			cylinder.radial_segments = 8
			mesh.mesh = cylinder
			mesh.material_override = material
			mesh.position = Vector3(float(part % 2) * 0.14 - 0.07, -0.16, float(part / 2) * 0.14 - 0.07)
			if id == "copper_1": mesh.rotation.z = PI * 0.5
			art.add_child(mesh)

func _sync_finds() -> void:
	for id in ["cash_1", "cash_2", "cash_3", "copper_1"]:
		targets[id].get_node("Find").visible = not sim.collected.has(id)

func _make_target(id: String, location: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.set_meta("interaction_id", id)
	area.name = id + "_interaction"
	area.position = location
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	area.add_child(collider)
	add_child(area)
	targets[id] = area

func _unhandled_input(event: InputEvent) -> void:
	if not spawned: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			sound.muted = not sound.muted
			hud.show_receipt("the block goes quiet." if sound.muted else "the block continues.")
		if event.physical_keycode == KEY_ESCAPE:
			if mode == "playing": _pause()
			elif mode != "title": _resume()
			get_viewport().set_input_as_handled()
			return
		if mode == "playing":
			if event.physical_keycode == KEY_E:
				var hit := _ray(3.2)
				if not hit.is_empty():
					var current_id := str(hit.collider.get_meta("interaction_id", ""))
					if not current_id.is_empty(): _interact(current_id)
			if event.physical_keycode == KEY_I: _pockets()
	if mode != "playing": return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.0022)
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.25, 1.25)
		camera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _punch()

func _physics_process(delta: float) -> void:
	if not spawned: return
	hud.update_stats(sim, _zone())
	if mode != "playing": return
	if OS.has_feature("web") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_pause()
		return
	clock += delta
	world.set_day_time(sim.day_time)
	var motion := Input.get_vector("left", "right", "forward", "back")
	var direction := player.transform.basis * Vector3(motion.x, 0, motion.y)
	var sprinting := Input.is_action_pressed("sprint") and motion.length() > 0.01
	var speed: float = 3.6 * sim.speed_multiplier() * (1.7 if sprinting else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = -1.0 if player.is_on_floor() else player.velocity.y - 16.0 * delta
	player.move_and_slide()
	if player.position.y < -5.0: _respawn()
	var at_block := Vector2(player.position.x, player.position.z - 4).length() < 5.5
	var events: Array = sim.tick(delta, sprinting, at_block)
	for event: String in events:
		if event == "crash":
			sound.play_sound("crash")
			hud.show_receipt("the crash arrives.\non schedule.")
		if event == "death": _death()
		if event == "day":
			hud.show_receipt("day %d.\nit is approximately tuesday." % sim.day)
			_restore_enemy()
			_sync_finds()
	attack_cd = maxf(0, attack_cd - delta)
	attack_time = maxf(0, attack_time - delta)
	if enemy_recoil > 0:
		enemy_recoil = maxf(0.0, enemy_recoil - delta)
		actors.lurch.get_node("Art").position.z = 0.10 * enemy_recoil / 0.12
	hands.position.y = sin(clock * 8.0) * 0.012 * motion.length()
	Art.animate_character(hands, "player_hands", clock, motion.length(), (0.22 - attack_time) / 0.22 if attack_time > 0 else 0.0)
	_tick_enemy(delta)
	_tick_possum(delta)
	_animate_people(delta)
	var hit := _ray(3.2)
	target_id = ""
	if not hit.is_empty(): target_id = str(hit.collider.get_meta("interaction_id", ""))
	hud.prompt.text = _prompt(target_id)

func _ray(distance: float, areas: bool = true) -> Dictionary:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * distance, 7)
	query.collide_with_areas = areas
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _prompt(id: String) -> String:
	if id.is_empty(): return ""
	var names := {"tony":"TRE BAG TONY", "pete":"PAWN SHOP PETE", "yuri":"YURI", "block":"THE BLOCK", "possum":"THE POSSUM", "brutus":"BRUTUS"}
	if id == "lurch": return "LURCH  /  %d\nsmells like ham." % ceili(enemy_hp) if enemy_hp > 0 else "LURCH\nremains here."
	if id.begins_with("dumpster"): return "THE DUMPSTER\n[E] look inside" if not sim.collected.has(id) else "THE DUMPSTER\nempty. you know."
	if id.begins_with("cash"): return "[E] loose change" if not sim.collected.has(id) else "the money was here."
	if id == "copper_1": return "[E] pure copper" if not sim.collected.has(id) else "the copper has left."
	return "%s\n[E] %s" % [names.get(id, id), "consult the crate" if id == "block" else "bother"]

func _interact(id: String) -> void:
	if mode != "playing": return
	match id:
		"tony":
			_dialogue("TRE BAG TONY", "three coats. ten dollars. simple math.\ntony does not blink.", [
				_option("buy a rock. $10.", _act.bind("buy_rock", ""), sim.cash < 10),
				_option("try to negotiate.", _say.bind("tony explains, slowly, that he does not negotiate.\n(this changes nothing.)"))])
		"pete":
			_dialogue("PAWN SHOP PETE", "pete is behind the glass.\nthe hot pocket is on this side of pete.", [
				_option("pawn a sock. $1.", _act.bind("pawn_sock", ""), sim.pete_paid >= 200),
				_option("sell junk. $1 each.", _act.bind("sell_junk", ""), sim.junk == 0 or sim.pete_paid >= 200),
				_option("sell pure copper. $15.", _act.bind("sell_copper_pete", ""), sim.copper == 0 or sim.pete_paid >= 200),
				_option("buy food. $3. (canned.)", _act.bind("buy_food", ""), sim.cash < 3)])
		"yuri":
			_dialogue("YURI", "what you bring, idiot.", [
				_option("sell pure copper. $25.", _act.bind("sell_copper_yuri", ""), sim.copper == 0),
				_option("ask about brutus.", _say.bind("BRUTUS REMEMBER. you know what you did.\n(you do not.)"))])
		"block":
			_dialogue("THE BLOCK", "the crate is still here.\nso are you.", [
				_option("smoke a rock. (-1 rock)", _act.bind("smoke", ""), sim.rocks == 0 or sim.high_remaining > 0),
				_option("check your pockets.", _pockets)])
		"possum":
			_dialogue("THE POSSUM", "the helmet is regulation.\nthe possum has not asked about yours.", [
				_option("ask what he knows.", _say.bind("the possum looks at the crate.\nthen at you.\nhe has a route."))])
		"brutus": _dialogue("BRUTUS", "he is 14.\nhe remembers.", [])
		"lurch": _say("lurch is the whole conversation.")
		"cash_1", "cash_2", "cash_3": _act("collect_cash", id)
		"copper_1": _act("collect_copper", id)
		"dumpster_1", "dumpster_2", "dumpster_3":
			if sim.collected.has(id):
				hud.show_receipt("the dumpster is empty.\nyou look anyway.")
				return
			_dialogue("THE DUMPSTER", "three things.\none hand available.", [
				_option("take the damp envelope. ($6)", _act.bind("dumpster_cash", id)),
				_option("take three pieces of junk.", _act.bind("dumpster_junk", id)),
				_option("take the can. (unmarked.)", _act.bind("dumpster_food", id))])

func _option(label: String, action: Callable, disabled: bool = false) -> Dictionary:
	return {"label": label, "action": action, "disabled": disabled}

func _dialogue(title: String, text: String, options: Array) -> void:
	mode = "dialogue"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options.append(_option("leave.", _resume))
	hud.menu(title, text, options)

func _act(action: String, target: String) -> void:
	if store.busy or loading: return
	# Controls are closed immediately after one action. Simulation independently validates spending.
	if action == "smoke" and Vector2(player.position.x, player.position.z - 4).length() > 6.0:
		_say("the crate is elsewhere.")
		return
	var result: Dictionary = sim.transact(action, target)
	_resume()
	hud.show_receipt(str(result.get("text", "")))
	if bool(result.get("ok", false)):
		_sync_finds()
		sound.play_sound(str(result.get("event", "pickup")))
		_save(false)

func _say(text: String) -> void:
	_resume()
	hud.show_receipt(text)

func _pockets() -> void:
	_dialogue("YOUR POCKETS", "junk %d · food %d · pure copper %d\nthe pockets contain what they contain." % [sim.junk, sim.food, sim.copper], [
		_option("eat the food. (+15 body)", _act.bind("eat_food", ""), sim.food == 0)])

func _title() -> void:
	if store.busy or loading: return
	mode = "title"
	hands.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu("ROCK BOTTOM", "approximately tuesday.\nthe block has not moved.", [
		_option("wake up.", _new_game), _option("remember.", _load),
		_option("leave.", _quit, OS.has_feature("web"))], true)

func _new_game() -> void:
	if store.busy or loading: return
	sim.fresh()
	_respawn()
	_restore_enemy()
	_sync_finds()
	sound.ready_for_sound = true
	_resume()
	hud.show_receipt("your mouth tastes like a battery.\nit is approximately tuesday.")

func _resume() -> void:
	if store.busy or loading: return
	mode = "playing"
	sound.ready_for_sound = true
	hud.close_menu()
	hands.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _pause() -> void:
	mode = "paused"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.menu("STILL HERE", "WASD move · mouse look · shift sprint\nE bother · left mouse swing · I pockets · M mute", [
		_option("continue.", _resume), _option("put it on file.", _save.bind(true)),
		_option("remember.", _load), _option("back to the curb.", _title)])

func _focus_lost() -> void:
	if mode == "playing": _pause()

func _quit() -> void:
	get_tree().quit()

func _save(show_message: bool = false) -> void:
	if store.busy:
		save_pending = true
		return
	var ok: bool = await store.write_save(sim.snapshot(player.position, player.rotation.y))
	if not ok: hud.show_receipt(store.last_error)
	elif show_message: hud.show_receipt("filed.\nthe drawer accepts this.")
	if save_pending:
		save_pending = false
		_save(false)

func _load() -> void:
	if store.busy or loading: return
	var was_title := mode == "title"
	loading = true
	mode = "loading"
	hud.menu("THE DRAWER", "paper moves.", [])
	var data: Dictionary = await store.read_save()
	if data.is_empty():
		loading = false
		if was_title: _title()
		else: _pause()
		hud.show_receipt(store.last_error if not store.last_error.is_empty() else "the drawer is empty.")
		return
	var placement: Dictionary = sim.restore(data)
	player.position = placement.position
	player.rotation.y = placement.yaw
	player.velocity = Vector3.ZERO
	# Dynamic overlap check runs after the scene's physics state is synchronized.
	await get_tree().physics_frame
	var shape := CapsuleShape3D.new()
	shape.radius = 0.31
	shape.height = 1.70
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), player.position + Vector3(0, 0.90, 0))
	query.collision_mask = 3
	query.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): _respawn()
	_restore_enemy()
	_sync_finds()
	loading = false
	if OS.has_feature("web"):
		mode = "paused"
		hud.menu("REMEMBERED", "the file remembers.\nthe block continues.", [_option("continue.", _resume)])
	else:
		_resume()
		hud.show_receipt("the file remembers.\nthe block continues.")

func _respawn() -> void:
	player.position = Vector3(0, 0.02, 8)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	pitch = -0.04
	camera.rotation.x = pitch

func _death() -> void:
	_respawn()
	_restore_enemy()
	hud.show_receipt("you eat curb.\nthe crate is still here.\ncred -10.")
	_save(false)

func _punch() -> void:
	if attack_cd > 0: return
	attack_cd = 0.28
	attack_time = 0.22
	sound.play_sound("hit")
	var hit := _ray(2.35, false)
	if hit.is_empty(): return
	var id := str(hit.collider.get_meta("interaction_id", ""))
	if id != "lurch" or enemy_hp <= 0: return
	enemy_hp -= sim.damage()
	var art: Node3D = actors.lurch.get_node("Art")
	art.position.z = 0.10
	enemy_recoil = 0.12
	if enemy_hp <= 0:
		enemy_hp = 0
		art.rotation.x = PI * 0.5
		art.position.y = 0.25
		actors.lurch.collision_layer = 0
		var result: Dictionary = sim.transact("defeat_lurch")
		hud.show_receipt(result.text)
		_save(false)

func _restore_enemy() -> void:
	var body: CharacterBody3D = actors.lurch
	var art: Node3D = body.get_node("Art")
	body.position = anchors.lurch
	body.velocity = Vector3.ZERO
	enemy_windup = 0
	enemy_cooldown = 1.0
	enemy_hit_ready = false
	enemy_recoil = 0.0
	enemy_hp = 0 if sim.defeated.has("lurch") else 120
	body.collision_layer = 0 if enemy_hp <= 0 else 2
	art.rotation.x = PI * 0.5 if enemy_hp <= 0 else 0.0
	art.position = Vector3(0, 0.25, 0) if enemy_hp <= 0 else Vector3.ZERO

func _tick_enemy(delta: float) -> void:
	if enemy_hp <= 0: return
	var body: CharacterBody3D = actors.lurch
	var offset := player.position - body.position
	offset.y = 0
	var distance := offset.length()
	var home: Vector3 = anchors.lurch
	var in_alley := player.position.distance_to(home) < 10
	var chase := distance < 7.5 and in_alley
	enemy_cooldown = maxf(0, enemy_cooldown - delta)
	if enemy_windup > 0:
		enemy_windup -= delta
		if enemy_windup <= 0 and enemy_hit_ready:
			enemy_hit_ready = false
			var query := PhysicsRayQueryParameters3D.create(body.position + Vector3.UP, player.position + Vector3.UP, 1)
			if distance < 2.0 and get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				var died: bool = sim.hurt(18.0)
				sound.play_sound("hurt")
				hud.show_receipt("lurch connects.\nbody -18.")
				if died: _death()
		return
	if chase and distance < 1.8 and enemy_cooldown <= 0:
		enemy_windup = 0.65
		enemy_hit_ready = true
		enemy_cooldown = 1.6
		hud.show_receipt("lurch winds up.")
		return
	var destination: Vector3 = player.position if chase else home
	var direction := destination - body.position
	direction.y = 0
	if direction.length() > (1.4 if chase else 0.15):
		direction = direction.normalized()
		body.velocity = direction * 1.6
		body.velocity.y = -2.0
		body.move_and_slide()
		body.rotation.y = atan2(direction.x, direction.z)

func _tick_possum(delta: float) -> void:
	var body: CharacterBody3D = actors.possum
	var next := Vector3(4 + sin(clock * 0.14) * 3.0, 0, 6 + cos(clock * 0.14) * 2.0)
	var direction := next - body.position
	if direction.length() > 0.05:
		body.velocity = direction.normalized() * minf(direction.length() / maxf(delta, 0.001), 0.7)
		body.velocity.y = -2.0
		body.move_and_slide()
		body.rotation.y = atan2(direction.x, direction.z)

func _animate_people(delta: float) -> void:
	for id: String in actors:
		var body: Node3D = actors[id]
		var previous: Vector3 = actor_positions.get(id, body.position)
		var travel := Vector2(body.position.x - previous.x, body.position.z - previous.z).length()
		actor_positions[id] = body.position
		if id == "lurch" and enemy_hp <= 0: continue
		var moving := clampf(travel / maxf(delta, 0.001) / (0.7 if id == "possum" else 1.6), 0.0, 1.0)
		var gesture := 1.0 - enemy_windup / 0.65 if id == "lurch" and enemy_windup > 0 else 0.0
		Art.animate_character(body.get_node("Art"), id, clock, moving, gesture)

func _zone() -> String:
	if player.position.x < -23: return "SCRAP YARD"
	if player.position.x > 22 and player.position.z > 5: return "BACK ALLEY"
	if player.position.z < -8: return "DEALER'S CORNER" if player.position.x > 5 else "PAWN SHOP"
	return "THE BLOCK"

func _qa_tour() -> void:
	# Explicit development CLI only; never reachable from shipped controls.
	await get_tree().process_frame
	await get_tree().process_frame
	_new_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	store.save_path = ProjectSettings.globalize_path("res://../.build/3d/qa-save.json")
	for pair in [["cash_1", "collect_cash"], ["cash_2", "collect_cash"], ["cash_3", "collect_cash"]]:
		sim.transact(pair[1], pair[0])
	sim.transact("buy_rock")
	player.position = Vector3(0, 0.02, 8)
	var accepted: Dictionary = sim.transact("smoke")
	print("3D TOUR: purchase and real smoke ", accepted.ok)
	if not accepted.ok or sim.high_remaining < 17.9:
		push_error("Rendered tour did not ignite a real high.")
		get_tree().quit(1)
		return
	var started := Time.get_ticks_msec()
	var crash_started := -1.0
	var cycle_finished := -1.0
	while Time.get_ticks_msec() - started < 27500:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		if sim.crash_remaining > 0 and crash_started < 0: crash_started = elapsed
		if crash_started > 0 and sim.crash_remaining <= 0 and cycle_finished < 0: cycle_finished = elapsed
	print("3D TOUR: timers ", sim.high_remaining, " / ", sim.crash_remaining)
	print("3D TOUR: observed crash at ", crash_started, "s; cycle complete at ", cycle_finished, "s")
	if sim.high_remaining > 0 or sim.crash_remaining > 0 or absf(crash_started - 18.0) > 0.75 or absf(cycle_finished - 26.0) > 0.75:
		get_tree().quit(1)
		return
	await store.write_save(sim.snapshot(player.position, player.rotation.y))
	var loaded: Dictionary = await store.read_save()
	print("3D TOUR: save schema ", loaded.get("schema", "missing"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var file: String = ProjectSettings.globalize_path("res://../.build/3d/playable.png")
		get_viewport().get_texture().get_image().save_png(file)
	print("3D TOUR: PASS")
	if DisplayServer.get_name() != "headless": await _capture_views()
	else: get_tree().quit()

func _capture_views() -> void:
	world.set_day_time(0)
	_title()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("title")
	_new_game()
	mode = "paused"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var views := [
		["block", Vector3(0, 0.05, 8), Vector3(1, 1.2, -7)],
		["tony", Vector3(18.3, 0.05, -10.5), Vector3(18, 1.3, -13)],
		["pete", Vector3(-18, 0.05, -7.6), Vector3(-18, 1.3, -12.2)],
		["lurch", Vector3(24, 0.05, 14.5), Vector3(27, 1.4, 14)]
	]
	for view: Array in views:
		player.position = view[1]
		camera.look_at(view[2])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_capture(view[0])
	print("3D CAPTURE: PASS")
	get_tree().quit()

func _capture(label: String) -> void:
	var file := ProjectSettings.globalize_path("res://../.build/3d/" + label + ".png")
	get_viewport().get_texture().get_image().save_png(file)
