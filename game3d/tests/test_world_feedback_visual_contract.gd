extends SceneTree
const Probe = preload("world_feedback_visual_probe.gd")
const Pool = preload("res://scripts/world_feedback.gd")
const State = preload("res://scripts/game_state.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Contact = preload("res://scripts/actor_contact.gd")
var checks := 0
var failures: Array[String] = []
var groups := 0
class PoseClock:
	extends RefCounted
	var last_advanced_ms := 0.0
class PoseScene:
	extends Node
	var runtime := PoseClock.new()
	var deltas: Array[float] = []
	func _sync_model_nodes(delta: float) -> void: deltas.append(delta)
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _source() -> String:
	return FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("world_feedback_visual_probe.gd"))
func _registry() -> void:
	_check(Probe.CASES.core.size() == 7 and Probe.CASES.authority.size() == 11,"exact finite case census")
	_check(Probe.CONTEXTS.core == 7 and Probe.CONTEXTS.authority == 13,"aim and impact contexts are separately counted")
	_check(Probe.COUNTS.size() == 18,"all18 source burst recipes accounted")
	for recipe: String in Probe.COUNTS: _check(recipe in Pool.RECIPES,"actual supported burst recipe "+recipe)
	for recipe: String in Pool.RECIPES: _check(Probe.COUNTS.has(recipe) or recipe in ["walking_dust","ambient_mote"],"only separately tested walking/ambient recipes may coexist "+recipe)
	var counts := {"essential":1,"melee_sparks":8,"melee_rust":3,"melee_flash":1,"bottle_break":12,"bottle_impact":10,"holy_impact":12,"tony_coat":24,"older_phase":20,"dumpster_rats":10,"trash_cash":6,"trash_rats":8,"possum_reveal":6,"ally_hit":4,"ranged_aim":1,"fallen_aim":4,"radio":1,"taser":10}
	_check(counts == Probe.COUNTS,"exact immutable birth census")
	_check(Probe.MAX_CONTEXTS == 24 and Probe.MAX_CAPTURES == 96 and Probe.MAX_WALL_MS == 300000,"global finite work and capture caps")
	_check(Probe.GROUND_MIDLIFE == ["trash_cash","trash_rats","dumpster","possum"],"exact four ground-burst midlife contexts")
	groups += 1
func _authority() -> void:
	var text: String = _source()
	for forbidden: String in ["feedback.accept(","feedback.advance_particles(","feedback.reset_epoch(","emit_event(","projectiles.append(","npcs.append(","npcs.erase(",".position =",".mesh =",".multimesh."]:
		_check(forbidden not in text,"visual probe does not manufacture source effects via "+forbidden)
	for expected: String in ["game.runtime.attack(","game.runtime.kick_can(","game.runtime.open_world_prop(","game.runtime.select_world_prop(","game.runtime.companions.tick_possum_reveal(","game.runtime.bosses.tick_after_actors(","game.runtime.director._ally(","game.runtime.combat.tick_police(","game.runtime.director.tick(STEP,wall_clock)","game.runtime.advance(STEP/1000.0"]:
		_check(expected in text,"real source command/step retained "+expected)
	_check("body.isCop =" not in text and '"isCop",false' not in text,"fatal cop is not reclassified as ordinary death")
	_check('event.kind == "arrest"' in text and 'event.kind == "death"' in text,"separate actual death/arrest ordering witnesses")
	_check("source death really removed police" in text and "_prior_essential()" in text,"lifecycle test requires real preexisting effects and removal")
	_check("game.process_mode = Node.PROCESS_MODE_DISABLED" not in text and "suspend_callbacks(game,game.hud)" in text and "await physics_frame" in text,"callback suspension keeps real collision participation")
	_check('"expected_overlap":found' in text and '"expected_ray_body":hit_body == body' in text and 'active_fixture.physics_sentinel = _physics_sentinel()' in text,"every fixture requires actual original-wall overlap and ray sentinels")
	groups += 1
func _evidence() -> void:
	var text: String = _source()
	for expected: String in ["--qa-full is required before FullScene construction","DisplayServer.get_name() != \"headless\"","RenderingServer.frame_post_draw","root.get_texture().get_image()","rendered.save_png(path)","FileAccess.get_sha256(path)","world offset cannot move actual camera, aim, FOV or HUD","opaque status glyph pixels remain fixed","source_hashes_available","global300s watchdog","completed_cases.size() == CASES[packet].size()","contexts.size() == CONTEXTS[packet]","fresh report path preserves older evidence"]:
		_check(expected in text,"honest rendered evidence guard "+expected)
	_check(text.find("if not _args()") < text.find("game = ObservedScene.new()"),"missing QA flag rejected before scene construction")
	_check("game.queue_free()" in text and "await process_frame\n\tquit(" in text,"cleanup occurs after callback frame returns")
	_check('"visual_review_required":true' in text and "not controller/campaign/performance acceptance" in text,"passing receipts cannot claim visual or gameplay acceptance")
	_check('"occluded":occluded' in text and "no_bounded_observer_pose" in text,"occlusion reports real world collider without invented blocker")
	_check('owner.begins_with("structures:")' in text and '"normal":hit.get("normal")' in text,"actual wall proof excludes floor and invisible bounds")
	_check('await _melee(id,"tony"' in text and '"layout_differences":_view_differences(pre_layout,before)' in text and '"capture_differences":differences' in text,"close canonical storefront fixture and exact before/after layout/capture diffs")
	_check('aged += await _advance_until(maxf(0.0,250.0-aged))' in text and 'record.midlife_admitted_ms = aged' in text and '"visibility_requires_image_review":true' in text,"midlife capture preserves actual owner aging and honest image evidence")
	_check('game.prop_view.collider(str(selected.id))' in text and '"pre_trigger_frame":preframe' in text,"trash frame binds exact selected real prop before feedback context")
	_check('"source_prop_occluded"' in text and '"intervening_geometry"' in text and 'snapshot.particles.slice(0,220)' in text,"finite actual particle rays distinguish source can from unrelated blocker")
	groups += 1
func _source_seeds() -> void:
	var cases := [{"seed":1,"draw":1015568748},{"seed":1456,"draw":3437452623},{"seed":1972,"draw":1380227}]
	var owner := State.new()
	for spec: Dictionary in cases:
		owner.rng_seed = int(spec.seed)
		var actual: float = owner.random_float()
		_check(owner.rng_seed == int(spec.draw) and actual == float(spec.draw)/4294967296.0,"actual GameState LCG exact integer/dyadic fixture "+str(spec.seed))
	_check(float(cases[0].draw)/4294967296.0 < 0.5 and float(cases[1].draw)/4294967296.0 >= 0.8,"source trash outcomes selected before command")
	_check(float(cases[2].draw)/4294967296.0 < 0.25*Probe.STEP/1000.0,"radio source threshold at actual STEP")
	var next_draw: int = (((1*1664525+1013904223)&0xffffffff)*1664525+1013904223)&0xffffffff
	_check(float(next_draw)/4294967296.0 >= 0.04,"dumpster seed does not select optional far hitter before rats")
	groups += 1
func _callback_scope() -> void:
	var scene := Node3D.new(); var hud := Node.new(); var wall := StaticBody3D.new()
	root.add_child(scene); scene.add_child(hud); scene.add_child(wall)
	scene.set_process(true); hud.set_process(true); scene.set_physics_process(true); hud.set_physics_process(true)
	scene.set_process_input(true); scene.set_process_unhandled_input(true)
	_check(wall.disable_mode == CollisionObject3D.DISABLE_MODE_REMOVE and wall.can_process(),"default real-body removal policy with inherited active mode")
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not wall.can_process(),"old tree-disabled fixture disables inherited collider participation")
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	var mode: int = scene.process_mode; var wall_mode: int = wall.process_mode; var disable: int = wall.disable_mode
	Probe.suspend_callbacks(scene,hud)
	_check(scene.process_mode == mode and wall.process_mode == wall_mode and wall.disable_mode == disable and wall.can_process(),"new suspension leaves original collision modes active")
	_check(not scene.is_processing() and not hud.is_processing() and not scene.is_physics_processing() and not hud.is_physics_processing(),"source/HUD callback clocks held independently")
	_check(not scene.is_processing_input() and not scene.is_processing_unhandled_input(),"source input callbacks held")
	scene.free(); groups += 1
func _source_can_sightline() -> void:
	var can := StaticBody3D.new(); var other := StaticBody3D.new()
	can.set_meta("source_owner","interactiveProps:0"); other.set_meta("source_owner","interactiveProps:0")
	_check(Probe.source_can_occlusion({"collider":can},can),"exact selected canonical can can hide its own ground anchor")
	_check(not Probe.source_can_occlusion({"collider":other},can),"same owner metadata on a different body cannot bypass a wall")
	_check(not Probe.source_can_occlusion({},can) and not Probe.source_can_occlusion({"collider":can},null),"empty ray and absent explicit source body are not source-can occlusion")
	for owner: String in ["interactiveProps:5","interactiveProps:6","interactiveProps:00","structures:building_01","props:4",""]:
		can.set_meta("source_owner",owner)
		_check(Probe.source_can_occlusion({"collider":can},can) == (owner == "interactiveProps:5"),"only exact canonical can0..5 owner "+owner)
	can.free(); other.free(); groups += 1
func _source_contact_candidates() -> void:
	var player := {"id":"player","x":1050.0,"y":840.0,"w":24.0,"h":28.0}
	var spawn: Vector2 = Combat.center(player)
	for shape: Dictionary in [{"id":"tony","x":1620.0,"y":870.0,"w":28.0,"h":32.0},{"id":"brendan","x":200.0,"y":200.0,"w":26.0,"h":30.0}]:
		var offsets: Array[Vector2] = Probe.contact_offsets(player,shape)
		_check(offsets.size() == 16,"exact16 finite contact candidates "+str(shape.id))
		for offset: Vector2 in offsets:
			var body: Dictionary = shape.duplicate(true)
			var origin: Vector2 = spawn+offset-Vector2(body.w,body.h)*0.5
			body.x = origin.x; body.y = origin.y
			_check(offset.is_finite() and Combat.overlaps(player,body) and not Contact.penetrating(body,origin,player),"candidate lies in unchanged strict source contact band "+str(shape.id))
		_check(is_equal_approx(offsets[0].y,(player.h+shape.h)*0.5-0.5) and absf(offsets[0].x) < 0.00001,"first candidate uses real logical depth rather than26px radius")
	var old_accepts := 0
	for index: int in range(8):
		var offset: Vector2 = Vector2.from_angle(PI/4.0+float(index)*TAU/8.0)*26.0
		var body := {"id":"tony","x":spawn.x+offset.x-14.0,"y":spawn.y+offset.y-16.0,"w":28.0,"h":32.0}
		if Combat.overlaps(player,body) and not Contact.penetrating(body,Vector2(body.x,body.y),player): old_accepts += 1
	_check(old_accepts == 0,"old26px ring has no valid Tony strict-overlap/nonpenetration witness")
	_check(Probe.contact_offsets(player,{}).is_empty(),"invalid footprint cannot invent contact candidates")
	var text: String = _source()
	_check('"pair_cap":256' in text and 'Combat.overlaps(first.geometry,second.geometry)' in text and '"exact_actual_placement":exact' in text and '"can_hit":line' in text,"real-world pair still requires bounded disjoint actual placement/LOS proofs")
	_check(text.find('active_fixture.contact_search.selected = [first,second]') < text.find('body.x = point.x; body.y = point.y'),"initial actor writes follow complete pair preflight")
	groups += 1
func _incidental_mote_expiry() -> void:
	var snapshot := {"epoch":7,"particles":[{"serial":21,"recipe":"ambient_mote","life":6000.0},{"serial":22,"recipe":"bottle_impact","life":600.0},{"serial":23,"recipe":"bottle_impact","life":600.0}]}
	var before: Dictionary = snapshot.duplicate(true)
	var tracked: Dictionary = Probe.context_birth_serials(snapshot,["bottle_impact"])
	_check(tracked == {22:true,23:true} and snapshot == before,"context tracks only declared bursts without changing full mixed pool")
	_check(Probe.retained_context_births(snapshot,tracked,7) == 2,"retained original bursts still fail expiry beside a long-lived mote")
	var later := {"epoch":7,"particles":[{"serial":21,"recipe":"ambient_mote","life":4500.0},{"serial":24,"recipe":"bottle_impact","life":600.0}]}
	_check(Probe.retained_context_births(later,tracked,7) == 0 and later.particles.size() == 2,"old impact expiry ignores retained mote and new later same-recipe birth")
	later.particles.append({"serial":23,"recipe":"bottle_impact","life":1.0})
	_check(Probe.retained_context_births(later,tracked,7) == 1,"one unexpired original burst cannot be hidden by incidental expiration")
	later.epoch = 8
	_check(Probe.retained_context_births(later,tracked,7) == 0,"new-epoch serial reuse cannot substitute an original birth")
	var text: String = _source()
	_check('context_birth_serials(snapshot,recipes)' in text and 'remain = retained_context_births(now,born_serials,epoch) > 0' in text and 'while aged < 2200.0 and remain:' in text,"real context uses recipe-scoped identities and unchanged2200ms bound")
	groups += 1
func _admitted_pose_clock() -> void:
	var scene := PoseScene.new()
	for admitted: float in [0.0,1000.0/60.0,50.0,0.0]:
		scene.runtime.last_advanced_ms = admitted
		var count: int = scene.deltas.size()
		_check(Probe.sync_admitted_pose(scene) == admitted and scene.deltas.size() == count+1 and scene.deltas.back() == admitted/1000.0,"one exact admitted pose call, including zero hitpause: "+str(admitted))
	_check(scene.deltas[0] == 0.0 and scene.deltas[3] == 0.0,"no epsilon pose advancement during source hold")
	scene.free()
	var text: String = _source()
	_check(text.count("\t\t_pose_step()") == 2,"aging and projectile loops each synchronize admitted pose exactly once")
	_check('admitted += game.runtime.last_advanced_ms\n\t\t_pose_step()\n\t\t_resolve()' in text,"aging follows actual Runtime then pose then Scene events")
	_check('\t\t_pose_step()\n\t\tfired = fired' in text,"projectile pose precedes impact receipt and event consumption")
	var paint: String = text.get_slice("func _paint() -> void:",1).get_slice("func _capture(",0)
	_check('game._sync_model_nodes(0.0)' in paint and '_pose_step()' not in paint,"painting remains zero-delta with frozen clocks")
	_check('"direct owner command before next admitted pose step"' in text and '"capture_pose_changes":poses_before != poses_after' in text,"birth boundary and capture pose freeze are explicit evidence")
	groups += 1
func _actual_pose_contract() -> void:
	var snapshot := {"action":"charge","action_serial":9,"contact":true,"dead":false,"coat_count":0,"grounded":true,"hurt":0.5}
	var rig := {"frame":5,"last_coats":0,"last_state":["charge",9,true,false,0,true,true,false],"supported_actions":["charge"],"layers":[{"layer":1,"total":2,"visible":0},{"layer":2,"total":3,"visible":0},{"layer":3,"total":1,"visible":0}]}
	_check(Probe.pose_mismatches(snapshot,rig).is_empty(),"current phase3 snapshot matches zero actually visible coat meshes")
	var old: Dictionary = rig.duplicate(true); old.frame = 0; old.last_coats = 3; old.last_state[4] = 3
	for row: Dictionary in old.layers: row.visible = row.total
	_check(not Probe.pose_mismatches(snapshot,old).is_empty(),"old reset three-coat active image cannot pass")
	for index: int in [1,2,3,4,5,6]:
		var changed: Dictionary = rig.duplicate(true)
		changed.last_state[index] = 0 if index in [1,4] else not bool(changed.last_state[index])
		if index == 4: changed.last_state[index] = 3
		_check(not Probe.pose_mismatches(snapshot,changed).is_empty(),"serial/contact/dead/coats/ground/hurt mismatch rejects: "+str(index))
	var changed: Dictionary = rig.duplicate(true); changed.last_state[0] = "talk"
	_check("explicit_action" in Probe.pose_mismatches(snapshot,changed),"supported actual action cannot be replaced by ambient pose")
	changed = rig.duplicate(true); changed.layers[2].visible = 1
	_check("layer:3" in Probe.pose_mismatches(snapshot,changed),"last_coats field alone cannot conceal a visible outer coat")
	changed = rig.duplicate(true); changed.last_state[0] = ""; changed.supported_actions = []
	_check(Probe.pose_mismatches(snapshot,changed).is_empty(),"ordinary rig unsupported-action filtering remains authoritative")
	var empty_action: Dictionary = snapshot.duplicate(true); empty_action.action = ""
	changed = rig.duplicate(true); changed.last_state[0] = "talk"; changed.last_state[7] = true
	_check(Probe.pose_mismatches(empty_action,changed).is_empty(),"FullScene owns idle ambient fallback when Director has no explicit action")
	_check(not Probe.pose_mismatches({},rig).is_empty(),"missing Director cannot falsely prove current actor pose")
	var receipt := {"actor":{"id":"cop_4"},"detached_source_cop_id":"brendan"}
	for id: String in ["essential","melee","tony2","tony3","older2","older3","ranged-aim","ranged-impact","fallen-aim","fallen-impact","possum","ally","death_then_taser","radio","taser","taser_fatal","trash_cash"]:
		_check(Probe.context_pose_targets(id,receipt).size() <= 2,"bounded target-specific evidence: "+id)
	_check(Probe.context_pose_targets("death_then_taser",receipt) == ["tony","brendan"] and Probe.context_pose_targets("taser",receipt) == ["cop_4"],"actual dynamic source IDs are retained in pose evidence")
	groups += 1
func _opaque_hud_contract() -> void:
	var size := Vector2(220,20); var minimum := Vector2(32,20)
	var scaled := Transform2D(Vector2(0.75,0),Vector2(0,0.75),Vector2(24,450))
	var rect: Rect2i = Probe.opaque_fill_rectangle(size,1.0,minimum,scaled,Vector2i(960,540))
	_check(rect == Rect2i(26,452,161,11),"actual960 stretched meter interior uses pinned draw rule and2px inset")
	_check(Probe.opaque_fill_rectangle(size,0.5,minimum,scaled,Vector2i(960,540)) == Rect2i(26,452,90,11),"current half-filled meter excludes background remainder")
	_check(Probe.opaque_fill_rectangle(size,1.0,minimum,Transform2D(0.0,Vector2(32,600)),Vector2i(1280,720)) == Rect2i(34,602,216,16),"1280 meter proof uses same geometry without extra scaling")
	for ratio: float in [0.0,-1.0,INF,NAN,1.01]: _check(not Probe.opaque_fill_rectangle(size,ratio,minimum,scaled,Vector2i(960,540)).has_area(),"invalid/empty fill cannot contribute evidence")
	_check(not Probe.opaque_fill_rectangle(size,1.0,minimum,Transform2D(0.2,Vector2.ZERO),Vector2i(960,540)).has_area(),"rotated meter rejected rather than sampling its bounding box")
	var style := StyleBoxFlat.new(); style.bg_color = Color("aaa269")
	_check(Probe.opaque_fill_style(style),"plain opaque source style admitted")
	style.bg_color.a = 0.78; _check(not Probe.opaque_fill_style(style),"translucent plate excluded"); style.bg_color.a = 1.0
	style.border_width_left = 1; _check(not Probe.opaque_fill_style(style),"bordered style rejected"); style.border_width_left = 0
	style.corner_radius_top_left = 4; _check(not Probe.opaque_fill_style(style),"rounded style rejected"); style.corner_radius_top_left = 0
	style.skew = Vector2(0.1,0); _check(not Probe.opaque_fill_style(style),"skewed style rejected"); style.skew = Vector2.ZERO
	var first: Image = Image.create(32,16,false,Image.FORMAT_RGBA8); first.fill(Color(0.1,0.1,0.1,1))
	for x: int in range(3): first.set_pixel(x,0,Color("e8c040"))
	for x: int in range(12): first.set_pixel(x,8,Color("aaa269"))
	var second: Image = first.duplicate()
	var glyphs: Array[Vector2i] = Probe.foreground_mask(first,Rect2i(0,0,32,1),Color("e8c040"))
	var fill: Array[Vector2i] = Probe.foreground_mask(first,Rect2i(0,8,32,1),Color("aaa269"))
	var combined: Array[Vector2i] = Probe.unique_foreground(glyphs,fill)
	var proof: Dictionary = Probe.foreground_comparison(first,second,combined)
	_check(glyphs.size() == 3 and fill.size() == 12 and proof.pixels == 15 and proof.equal,"three glyph pixels plus actual opaque fill exceed unchanged12 threshold")
	_check(Probe.foreground_comparison(first,second,glyphs).pixels < 12,"old glyph-only evidence remains insufficient")
	_check(Probe.unique_foreground(glyphs,glyphs).size() == 3,"duplicate pixels cannot pad proof count")
	second.set_pixel(31,15,Color.WHITE)
	_check(Probe.foreground_comparison(first,second,combined).equal,"world/background changes excluded from actual foreground mask")
	second.set_pixel(0,8,Color("000000"))
	_check(not Probe.foreground_comparison(first,second,combined).equal,"one altered opaque meter pixel fails exact byte comparison")
	first.set_pixel(1,8,Color(170.0/255.0,162.0/255.0,105.0/255.0,0.78))
	_check(Probe.foreground_mask(first,Rect2i(0,8,32,1),Color("aaa269")).size() == 11,"matching RGB with translucent alpha cannot enter opaque mask")
	groups += 1
func _run() -> void:
	_registry(); _authority(); _evidence(); _source_seeds(); _callback_scope(); _source_can_sightline(); _source_contact_candidates(); _incidental_mote_expiry()
	_admitted_pose_clock(); _actual_pose_contract(); _opaque_hud_contract()
	_check(groups == 11,"all eleven contract groups completed")
	for failure: String in failures: push_error(failure)
	print("ACTUAL DOMAIN FEEDBACK VISUAL CONTRACT: ","PASS" if failures.is_empty() else "FAIL"," (",checks," checks; no renderer/visual acceptance)")
	quit(0 if failures.is_empty() else 1)
