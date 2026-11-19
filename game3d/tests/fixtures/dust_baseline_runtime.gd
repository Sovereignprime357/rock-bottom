class_name RockBottomDustBaselineRuntime
extends RefCounted
## Single full-model composition. Presentation and IO consume events after committed commands.
const State = preload("res://scripts/game_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Vendors = preload("res://scripts/vendors_core.gd")
const Content = preload("res://scripts/content_catalog.gd")
const Combat = preload("res://scripts/combat_system.gd")
const Director = preload("res://scripts/actor_director.gd")
const Bosses = preload("res://scripts/boss_system.gd")
const OldSchool = preload("res://scripts/old_school.gd")
const Travel = preload("res://scripts/travel_system.gd")
const Residents = preload("res://scripts/resident_dialogue.gd")
const Quests = preload("res://scripts/quest_dialogue.gd")
const Street = preload("res://scripts/street_dialogue.gd")
const Robbery = preload("res://scripts/robbery_system.gd")
const Rhythm = preload("res://scripts/rhythm_system.gd")
const Communications = preload("res://scripts/communications_system.gd")
const Props = preload("res://scripts/prop_state.gd")
const Heists = preload("res://scripts/heist_system.gd")
const Campaign = preload("res://scripts/campaign_system.gd")
const Days = preload("res://scripts/day_system.gd")
const Lockpick = preload("res://scripts/lockpick_system.gd")
const Companions = preload("res://scripts/companion_system.gd")
const Office = preload("res://scripts/office_campaign.gd")
const Cooking = preload("res://scripts/cooking_system.gd")
const WorldProps = preload("res://scripts/world_prop_actions.gd")
const Kingdom = preload("res://scripts/kingdom_campaign.gd")
const InteractiveProps = preload("res://scripts/interactive_prop_actions.gd")
const Guidance = preload("res://scripts/guidance_view.gd")
const Utilities = preload("res://scripts/neighborhood_utilities.gd")
const Incidents = preload("res://scripts/incident_system.gd")
const IncidentPaths = preload("res://scripts/incident_path_map.gd")
const IncidentCorridors = preload("res://scripts/incident_corridors.gd")
const AmbientAudio = preload("res://scripts/ambient_audio.gd")
const DistrictBorder = preload("res://scripts/district_border_view.gd")
const WallMarkings = preload("res://scripts/wall_markings.gd")
const Feedback = preload("res://scripts/world_feedback.gd")
const FeedbackAnchors = preload("res://scripts/world_feedback_anchors.gd")
const STEP_MS := 1000.0 / 60.0
var feedback: RefCounted = Feedback.new(9137)
var _feedback_anchors: RefCounted = FeedbackAnchors.new()
var _feedback_player: Dictionary = {}
var _feedback_state: Dictionary = {}
var _feedback_bound: bool = false
var _feedback_epoch: int = 0
var _feedback_cursor: int = 0
var _feedback_right := Vector3.RIGHT
var _feedback_stats := {"accepted":0,"rejected":0,"resets":0,"last_reset":""}
var state: RefCounted
var memory: RefCounted
var progression: RefCounted
var inventory: RefCounted
var vendors: RefCounted
var travel: RefCounted
var residents: RefCounted
var quests: RefCounted
var street: RefCounted
var robbery: RefCounted
var rhythm: RefCounted
var communications: RefCounted
var props: RefCounted
var heists: RefCounted
var campaign: RefCounted
var days: RefCounted
var lockpick: RefCounted
var companions: RefCounted
var office: RefCounted
var cooking: RefCounted
var world_props: RefCounted
var kingdom: RefCounted
var guidance: RefCounted
var utilities: RefCounted
var interactive_props: RefCounted
var incidents: RefCounted
var incident_paths: RefCounted
var incident_corridors: RefCounted
var _incident_failure: String = ""
var _cart_enabled: bool = false
var ambient_audio: RefCounted
var wall_markings: RefCounted
var _pending_lifecycle: Dictionary = {}
var _presentation_tasks: Array[Dictionary] = []
var _transition_events: Array[Dictionary] = []
var days_enabled: bool = false
var combat: RefCounted
var director: RefCounted
var bosses: RefCounted
var old_school: RefCounted
var _actors_enabled: bool = false
var _wall_ms: float = 0.0
var _wall_started: bool = false
var _spatial: WeakRef
var _outbox: Array[Dictionary] = []
var _save_wanted: bool = false
var _elapsed_ms: float = 0.0
var last_advanced_ms: float = 0.0
var profile_enabled: bool = false
var profile_us: Dictionary = {}
var profile_calls: Dictionary = {}
var p: Dictionary:
	get: return state.p
var s: Dictionary:
	get: return state.s

func _init(spatial_adapter: Object, boss_adapter: Object = null, unix_ms: Callable = Callable()) -> void:
	_spatial = weakref(spatial_adapter) if spatial_adapter != null else null
	state = State.new()
	_feedback_reset("cold",true)
	ambient_audio = AmbientAudio.new(state)
	wall_markings = WallMarkings.new(state)
	props = Props.new(state)
	var clock_source: Callable = unix_ms if unix_ms.is_valid() else func(): return Time.get_unix_time_from_system()*1000.0
	communications = Communications.new(state,props,clock_source)
	memory = Memory.new(state)
	progression = Progression.new(state)
	inventory = Inventory.new(state)
	vendors = Vendors.new(state,spatial_adapter,memory,boss_adapter)
	travel = Travel.new(state,spatial_adapter)
	residents = Residents.new(state,spatial_adapter,memory)
	quests = Quests.new(state,spatial_adapter,memory)
	rhythm = Rhythm.new(state,spatial_adapter,memory)
	street = Street.new(state,spatial_adapter,memory,travel,rhythm,communications)
	robbery = Robbery.new(state)
	lockpick = Lockpick.new(state)
	heists = Heists.new(state,spatial_adapter,lockpick)
	companions = Companions.new(state,spatial_adapter,communications,lockpick)
	world_props = WorldProps.new(state,spatial_adapter,props,memory,companions)
	utilities = Utilities.new(state,spatial_adapter)
	campaign = Campaign.new(state,spatial_adapter,progression,travel,communications,memory)
	days = Days.new(state,spatial_adapter,progression,travel,campaign,communications,clock_source)
	campaign.bind_day_owner(days); travel.bind_day_owner(days)
	days_enabled = days.install()
	office = Office.new(state,spatial_adapter,campaign,progression,travel)
	cooking = Cooking.new(state,spatial_adapter)
	s.mode = "title"
	state.drain_events()

func _reachable(id: String) -> bool:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	return adapter != null and adapter.has_method(&"can_reach_target") and adapter.call(&"can_reach_target",id) == true

func fresh() -> bool:
	if cooking.is_resolving(): return _defer_lifecycle("fresh")
	cooking.cancel("fresh"); _presentation_tasks.clear(); _transition_events.clear(); _pending_lifecycle = {}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close()
	residents.close()
	quests.close()
	travel.cancel_travel("fresh")
	_outbox.clear(); _save_wanted = false; _elapsed_ms = 0.0
	if not state.fresh(): return false
	_feedback_reset("fresh",true)
	companions.ready()
	props.reset_session("fresh")
	if not _reset_cart_incidents("fresh"): return false
	world_props.reset_session("fresh")
	if interactive_props != null:
		if not interactive_props.reset_session("fresh"): return false
		_sync_interactive_props()
	if not wall_markings.prepare_start("fresh"): return false
	utilities.reset_session("fresh")
	if kingdom != null: kingdom._sync_epoch()
	if _actors_enabled and (not bosses.normalize_state() or not _prepare_actor_placements()):
		s.mode = "paused"; return false
	if days_enabled and not campaign.refresh_forces(): return false
	s.mode = "playing"
	memory.normalize_state()
	state.emit_event("placement_reset",{"source_position":state.player_center(),"reason":"fresh"})
	_publish_start(false)
	return true

func restore(data: Variant) -> bool:
	if not data is Dictionary: return false
	# The low-level codec returns fresh defaults on a rejected envelope. The live controller
	# validates that envelope first so a bad file cannot erase the current play session.
	var schema: Variant = data.get("schema")
	if not (schema is int or schema is float) or not is_finite(float(schema)): return false
	if schema != 1 and schema != 2: return false
	if schema == 2 and (data.get("format") != State.SAVE_FORMAT or not data.get("player") is Dictionary or not data.get("state") is Dictionary): return false
	# Source load preserves the array/non-array distinction until startGame.
	# The normalized rows remain authoritative; never restore raw saved rewards.
	var needs_hustles: bool = schema == 1 or not data.state.get("hustles") is Array
	if _actors_enabled:
		var candidate: RefCounted = State.new()
		var candidate_progression := Progression.new(candidate)
		var candidate_campaign := Campaign.new(candidate,null,candidate_progression)
		if candidate.restore(data).get("ok") != true: return false
		var adapter: Object = _spatial.get_ref() if _spatial != null else null
		var candidate_combat: RefCounted = Combat.new(candidate,adapter)
		var candidate_bosses: RefCounted = Bosses.new(candidate,candidate_combat)
		if not candidate_bosses.normalize_state(): return false
	if cooking.is_resolving(): return _defer_lifecycle("restore",data.duplicate(true))
	cooking.cancel("restore"); _presentation_tasks.clear(); _transition_events.clear(); _pending_lifecycle = {}
	var previous_cart: Dictionary = travel.cart_record()
	var restored: Dictionary = state.restore(data)
	if restored.get("ok") != true: return false
	_feedback_reset("restore",true)
	companions.ready()
	props.reset_session("restore")
	if not _reset_cart_incidents("restore",previous_cart): return false
	world_props.reset_session("restore")
	if interactive_props != null:
		if not interactive_props.reset_session("restore"): return false
		_sync_interactive_props()
	# Preserve original presence, but never reinsert unbounded save values after State.restore.
	var wall_state: Dictionary = {}
	if schema == 2:
		for key: String in ["graffiti","posters"]:
			if data.state.has(key): wall_state[key] = s.get(key)
	if not wall_markings.prepare_start("restore",wall_state): return false
	# Source start order: interactive props -> walls -> equipment (already
	# normalized by State.restore) -> missing hustles -> route. Existing merged
	# campaign load-witness repairs must still precede the route unlock filter.
	if needs_hustles: progression.roll_hustles()
	utilities.reset_session("restore")
	if kingdom != null: kingdom._sync_epoch()
	if days_enabled and not campaign.reconcile_loaded_state().get("ok",false): return false
	vendors.session.close()
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	residents.close()
	quests.close()
	_outbox.clear(); _save_wanted = false; _elapsed_ms = 0.0
	if _actors_enabled and (not bosses.normalize_state() or not _prepare_actor_placements()):
		s.mode = "paused"
		state.emit_event("placement_blocked",{"reason":"boss_restore"})
		return false
	s.mode = "playing"
	progression.ensure_route()
	if days_enabled:
		if not campaign.refresh_forces(): return false
		days.rehydrate()
	state.emit_event("placement_reset",{"source_position":state.player_center(),"reason":"restore"})
	_publish_start(true)
	return true

func _publish_start(loaded: bool) -> void:
	# Source start.js143–153: these explicit handles consume no random draws.
	var first_intro: bool = not loaded and not s.flags.get("introDone",false)
	var text: String = "you wake up on the sidewalk.\nyour mouth tastes like a battery.\nyou do not remember.\n(Q to see what's next.)" if first_intro else "you wake up on the sidewalk.\nyour mouth tastes like a battery.\n(Q to see today's hustles.)"
	state.emit_event("toast",{"text":text,"duration_ms":4200 if first_intro else 3500})
	_feed("woke up.\nstill in the neighborhood.\nfeels like a tuesday.","@crackheadcent")
	_feed("good morning. tony has not blinked.","@tony_observer")
	var ranks: Array = state.content.catalogs.ranks
	state.emit_event("news",{"text":"good evening. "+str(ranks[int(p.rank)].name)+" is once again at large."})
	# Preserve earlier queued publications and source call-time silence, even if
	# presentation does not drain until a later input or frame.
	communications.flush_pending_events()

func snapshot() -> Dictionary: return state.snapshot()

func continue_after_ending() -> bool:
	if s.mode != "ending" or not s.get("endingContinue",false) or cooking.is_resolving(): return false
	if not set_mode("playing"): return false
	s.endingContinue = false; s.endingSavePromise = null
	state.emit_event("toast",{"text":"the block is still here.\nthe clipboard has another sheet.","duration_ms":2400})
	return true

func set_mode(mode: String) -> bool:
	if mode not in ["title","playing","paused","dialogue","cookmini","heist","ending"]: return false
	if mode == "cookmini": return cooking.is_active() and s.mode == "cookmini"
	if cooking.is_active():
		if cooking.is_resolving(): return _defer_lifecycle("mode",mode)
		cooking.cancel("mode")
	# Read-only journal/inventory also replace the Old School modal capability.
	_close_old_school()
	if mode != "dialogue": cooking.cancel("mode"); vendors.session.close()
	if mode != "dialogue": travel.close()
	if mode != "dialogue": residents.close()
	if mode != "dialogue": quests.close()
	if mode != "dialogue": street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); utilities.close()
	s.mode = mode
	return true

func close_dialogue() -> bool:
	if not cooking.cancel("close_dialogue"): return false
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close()
	travel.close()
	residents.close()
	quests.close()
	if s.mode == "dialogue": s.mode = "playing"
	return true

func open_vendor(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	travel.close()
	residents.close()
	quests.close()
	var result: Dictionary = vendors.open(id)
	_resolve_events()
	return result

func select_vendor(token: Variant, action: String) -> Dictionary:
	var result: Dictionary = vendors.select(token,action)
	try_intro_remember()
	_resolve_events()
	return result

func open_travel(service: String,page: int = 0) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close()
	residents.close()
	quests.close()
	var result: Dictionary = travel.open(service,page)
	_resolve_events()
	return result

func select_travel(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = travel.select(token,action)
	_resolve_events()
	return result

func open_resident(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close(); travel.close()
	quests.close()
	var result: Dictionary = residents.open(id)
	_resolve_events()
	return result

func select_resident(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = residents.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func open_quest(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close(); travel.close(); residents.close()
	var result: Dictionary = quests.open(id)
	_resolve_events()
	return result

func select_quest(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = quests.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func open_package() -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close(); travel.close(); residents.close()
	var result: Dictionary = quests.open_package()
	_resolve_events()
	return result

func open_street(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()
	vendors.session.close(); travel.close(); residents.close(); quests.close()
	var result: Dictionary = street.open(id)
	_resolve_events()
	return result

func select_street(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = street.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func open_heist(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	close_dialogue()
	var result: Dictionary = heists.open(id)
	_resolve_events()
	return result

func select_heist(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = heists.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func open_day_actor(id: String) -> Dictionary:
	if not cooking.cancel("replace_menu"): return {"ok":false,"reason":"resolution_pending"}
	close_dialogue()
	var result: Dictionary = days.open(id)
	_resolve_events()
	return result

func select_day_actor(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = days.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func sleep_at_block() -> Dictionary:
	var result: Dictionary = days.sleep_at_block()
	_resolve_events()
	return result

func open_companion(id: String) -> Dictionary:
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = companions.open(id)
	_resolve_events()
	return result

func select_companion(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = companions.select(token,action)
	_resolve_events()
	return result

func open_office(id: String) -> Dictionary:
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = office.open(id)
	_resolve_events()
	return result

func select_office(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = office.select(token,action)
	if result.get("reason") == "kingdom_actions_pending" and kingdom != null: result = kingdom.open_ledger()
	_resolve_events()
	return result

func _close_kingdom() -> void:
	if kingdom != null: kingdom.close()

func _close_old_school() -> void:
	if old_school != null: old_school.close()

func open_old_school() -> Dictionary:
	if old_school == null: return {"ok":false,"reason":"missing_dependency"}
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = old_school.open()
	_resolve_events()
	return result

func select_old_school(token: Variant,action: String) -> Dictionary:
	if old_school == null: return {"ok":false,"reason":"missing_dependency"}
	var result: Dictionary = old_school.select(token,action)
	_resolve_events()
	return result

func select_kingdom(token: Variant,action: String) -> Dictionary:
	if kingdom == null: return {"ok":false,"reason":"missing_dependency"}
	var result: Dictionary = kingdom.select(token,action)
	_resolve_events()
	return result

func use_kingdom(id: String,door: bool = false) -> Dictionary:
	if kingdom == null: return {"ok":false,"reason":"missing_dependency"}
	_close_old_school()
	var result: Dictionary = kingdom.use_door(id) if door else kingdom.use_target(id)
	_resolve_events()
	return result

func use_office_field(id: String) -> Dictionary:
	var result: Dictionary = office.use_field_target({"target_id":id})
	_resolve_events()
	return result

func open_zone(id: String) -> Dictionary:
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = utilities.open_zone(id)
	_resolve_events()
	return result

func select_utility(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = utilities.select(token,action)
	if result.get("ok",false):
		match result.get("handoff",""):
			"smoke": result = smoke("block")
			"sleep": result = sleep_at_block()
			"cooking": result = open_cooking()
			"package": result = open_package()
	_resolve_events()
	return result

func press_squint() -> Dictionary:
	var result: Dictionary = utilities.press_squint()
	_resolve_events()
	return result

func open_world_prop(id: String) -> Dictionary:
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = world_props.open(id)
	_resolve_events()
	return result

func select_world_prop(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = world_props.select(token,action)
	_resolve_events()
	return result

func open_cooking() -> Dictionary:
	if not close_dialogue(): return {"ok":false,"reason":"resolution_pending"}
	var result: Dictionary = cooking.open_menu()
	_resolve_events()
	return result

func select_cooking(token: Variant,mode: String) -> Dictionary:
	var result: Dictionary = cooking.select(token,mode)
	_resolve_events()
	return result

func lock_cooking() -> Dictionary:
	var result: Dictionary = cooking.lock()
	_resolve_events()
	return result

func bail_cooking() -> Dictionary:
	var result: Dictionary = cooking.bail()
	_resolve_events()
	return result

func request_save() -> void:
	_save_wanted = true

func _defer_lifecycle(kind: String,payload: Variant = null) -> bool:
	if not _pending_lifecycle.is_empty() and not _receipt_epoch(_pending_lifecycle): _pending_lifecycle = {}
	if _pending_lifecycle.is_empty(): _pending_lifecycle = {"kind":kind,"payload":payload,"player_epoch":p,"state_epoch":s}
	return false

func _receipt_epoch(receipt: Dictionary) -> bool:
	return is_same(receipt.get("player_epoch"),p) and is_same(receipt.get("state_epoch"),s)

func _guard_cooking_transition() -> void:
	if not _pending_lifecycle.is_empty() and not _receipt_epoch(_pending_lifecycle): _pending_lifecycle = {}
	for index: int in range(_transition_events.size()-1,-1,-1):
		if not _receipt_epoch(_transition_events[index]): _transition_events.remove_at(index)
	if s.mode == "cookmini" and not cooking.is_active():
		cooking.cancel("orphaned_heat"); s.mode = "playing"
	if not cooking.is_resolving() or s.mode == "cookmini": return
	# Legacy wall owners can write mode directly. Accepted settlement still owns
	# this surface until it finishes; preserve the destination, not a stalled mode.
	if s.mode in ["title","playing","paused","dialogue","heist","ending"]: _defer_lifecycle("mode",s.mode)
	s.mode = "cookmini"

func _hold_transition(event: Dictionary) -> void:
	for receipt: Dictionary in _transition_events:
		if _receipt_epoch(receipt) and receipt.event.kind == event.kind: return
	_transition_events.append({"event":event.duplicate(true),"player_epoch":p,"state_epoch":s})

func _death_cleanup(kind: String) -> void:
	if kingdom != null: kingdom.abort(false,false)
	travel.cancel_travel(kind)
	vendors.session.close(); residents.close(); quests.close()
	street.close(); rhythm.close(); heists.close(); days.close(); office.close(); companions.close(); world_props.close(); _close_kingdom(); _close_old_school(); utilities.close()

func _release_transitions() -> void:
	if cooking.is_resolving(): return
	var pending: Array[Dictionary] = _transition_events; _transition_events = []
	for receipt: Dictionary in pending:
		if not _receipt_epoch(receipt): continue
		var event: Dictionary = receipt.event
		if event.kind == "kingdom_ending_due":
			if s.mode in ["title","ending"] and kingdom != null: kingdom.commit_ending()
			continue
		if event.kind in ["ending_requested","ending"]:
			if s.mode not in ["title","ending"]: continue # Earlier lifecycle request won.
		elif event.kind in ["death","arrest"]: _death_cleanup(event.kind)
		_outbox.append(event)

func _apply_pending_lifecycle() -> void:
	if _pending_lifecycle.is_empty() or cooking.is_resolving(): return
	var pending: Dictionary = _pending_lifecycle; _pending_lifecycle = {}
	if not _receipt_epoch(pending): return
	var accepted: bool = false
	match pending.kind:
		"fresh": accepted = fresh()
		"restore": accepted = restore(pending.payload)
		"mode": accepted = set_mode(pending.payload)
	state.emit_event("lifecycle_applied",{"kind":pending.kind,"mode":s.mode,"ok":accepted})

func advance_presentation(seconds: float) -> bool:
	if not is_finite(seconds) or seconds <= 0: return false
	var step: float = minf(50.0,seconds*1000.0)
	if s.mode not in ["playing","cookmini"] and float(s.get("hitPause",0)) > 0:
		s.hitPause = maxf(0,float(s.hitPause)-step)
	return cooking.tick_presentation(step)

func attempt_robbery(actor: Dictionary) -> bool:
	return robbery.attempt(actor)

func select_activity(token: Variant,action: String) -> Dictionary:
	var result: Dictionary = rhythm.select(token,action)
	try_intro_remember(); _resolve_events()
	return result

func enable_actor_simulation() -> bool:
	if _actors_enabled: return true
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if adapter == null: return false
	for method: StringName in [&"move_body",&"clear_placement",&"can_hit",&"sweep_projectile"]:
		if not adapter.has_method(method): return false
	combat = Combat.new(state,adapter,inventory,self)
	kingdom = Kingdom.new(state,adapter,campaign,office,combat,memory,communications,days)
	bosses = Bosses.new(state,combat,kingdom)
	if _wall_started:
		kingdom.tick_wall(_wall_ms); bosses.tick_wall(_wall_ms)
	if not bosses.normalize_state() or not _prepare_actor_placements(): return false
	old_school = OldSchool.new(state,adapter,bosses)
	director = Director.new(state,combat)
	companions.bind_director(director)
	vendors.session.close()
	vendors = Vendors.new(state,adapter,memory,bosses)
	residents.close()
	residents = Residents.new(state,adapter,memory,combat,bosses)
	quests.close()
	quests = Quests.new(state,adapter,memory,combat,bosses)
	guidance = Guidance.new(state,progression,memory,office,kingdom,campaign)
	_actors_enabled = true
	return true

func enable_cart_projection() -> bool:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if adapter == null or not adapter.has_method(&"begin_cart_epoch") or not adapter.has_method(&"sync_cart") or not adapter.sync_cart(): return false
	_cart_enabled = true; return true

func _sync_cart() -> bool:
	if not _cart_enabled: return true
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	return adapter != null and adapter.sync_cart() == true

func _reset_cart_incidents(reason: String,previous_cart: Dictionary = {}) -> bool:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if not ambient_audio.reset_session(reason): return false
	if _cart_enabled and (adapter == null or adapter.begin_cart_epoch() != true): return false
	if incidents != null and not incidents.reset_session(reason): return false
	_incident_failure = ""
	travel.reset_session(reason,previous_cart)
	return _sync_cart()

func interact_cart() -> Dictionary:
	if not _cart_enabled: return {"ok":false,"reason":"missing_cart_projection"}
	var result: Dictionary = travel.interact_cart()
	if result.get("ok",false): _sync_cart()
	_resolve_events(); return result

func enable_incidents(world: Node3D) -> bool:
	if incidents != null: return incidents.ready()
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if adapter == null or world == null: return false
	var paths := IncidentPaths.new()
	if not paths.build(world).get("ok",false): return false
	var corridors := IncidentCorridors.new(paths,adapter,world)
	var model := Incidents.new(state,adapter,communications)
	if not model.bind_path_owner(paths) or not model.bind_corridor_owner(corridors) or not model.ready(): return false
	incident_paths = paths; incident_corridors = corridors; incidents = model
	return true

func _tick_incidents(step: float) -> void:
	if incidents == null: return
	if incidents.tick_active(step,not s.flags.get("introDone",false),communications.silence_active()):
		_incident_failure = ""; return
	var reason: String = str(incident_corridors.status().get("last_error","incident_dependency_unready"))
	if reason.is_empty(): reason = "incident_dependency_unready"
	if reason != _incident_failure:
		_incident_failure = reason
		state.emit_event("dependency_missing",{"system":"incidents","key":reason})

func enable_interactive_props() -> bool:
	if interactive_props != null: return interactive_props.ready()
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if not _actors_enabled or adapter == null or not adapter.has_method(&"stage_interactive_prop"): return false
	interactive_props = InteractiveProps.new(state,adapter,props,combat)
	return interactive_props.ready()

func _sync_interactive_props() -> void:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if interactive_props != null and adapter != null and adapter.has_method(&"sync_interactive_props"): adapter.sync_interactive_props()

func kick_can(id: String) -> Dictionary:
	if interactive_props == null or not _can_act(): return {"ok":false,"reason":"unavailable"}
	var result: Dictionary = interactive_props.kick(id)
	_sync_interactive_props(); _resolve_events()
	return result

func _prepare_actor_placements() -> bool:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if adapter == null or not adapter.has_method(&"clear_placement"): return false
	var planned: Array[Dictionary] = []
	for actor: Dictionary in state.npcs:
		if actor.get("dead",false): continue
		var point: Variant = adapter.call(&"clear_placement",combat._geometry(actor))
		if not point is Vector2 or not point.is_finite(): return false
		var bounds: Dictionary = state.content.world.bounds
		if point.x < 0 or point.y < 0 or point.x+float(actor.w) > float(bounds.w) or point.y+float(actor.h) > float(bounds.h): return false
		planned.append({"actor":actor,"position":point})
	for item: Dictionary in planned: item.actor.x = item.position.x; item.actor.y = item.position.y
	return true

func can_handle_death(actor: Dictionary) -> bool:
	return bosses != null and bosses.can_handle_death(actor)

func handle_death(id: String) -> bool:
	return bosses != null and bosses.handle_death(id)

func spawn_brutus_older() -> bool:
	return bosses != null and bosses.spawn_brutus_older()

func attack(forward: Vector2) -> Dictionary:
	if not _actors_enabled: return {"ok":false,"reason":"missing_combat"}
	var result: Dictionary = combat.attack_player(forward)
	_sync_interactive_props()
	_resolve_events()
	return result

func advance_wall(monotonic_ms: float) -> bool:
	if not is_finite(monotonic_ms) or monotonic_ms < _wall_ms: return false
	_resolve_events() # Death/arrest cancels pending travel before wall time advances.
	var elapsed: float = monotonic_ms-_wall_ms if _wall_started else 0.0
	_wall_ms = monotonic_ms; _wall_started = true
	var pending_receipts: Array[Dictionary] = []
	for receipt: Dictionary in _presentation_tasks:
		if not _receipt_epoch(receipt): continue
		if receipt.due > monotonic_ms: pending_receipts.append(receipt)
		else: state.emit_event("toast",receipt.payload)
	_presentation_tasks = pending_receipts
	communications.advance_wall(monotonic_ms)
	if days_enabled: days.tick_wall(monotonic_ms)
	companions.advance_wall(monotonic_ms)
	if _actors_enabled:
		combat.tick_wall(_wall_ms)
		bosses.tick_wall(_wall_ms)
		kingdom.tick_wall(_wall_ms)
	while elapsed > 0.0:
		var step: float = minf(240000.0,elapsed)
		travel.tick_real(step); elapsed -= step
	_resolve_events()
	return true

func _can_act() -> bool:
	return s.mode in ["playing","dialogue"] and float(p.stunT) <= 0.0

func smoke(spot_id: String) -> Dictionary:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if not _can_act() or adapter == null or not adapter.has_method(&"can_use_zone") or adapter.call(&"can_use_zone",spot_id) != true:
		return {"ok":false,"reason":"invalid_placement"}
	var result: Dictionary = memory.smoke(spot_id)
	_resolve_events()
	return result

func craft_hitter() -> Dictionary:
	if not _can_act(): return {"ok":false,"reason":"wrong_mode"}
	var result: Dictionary = memory.craft_hitter()
	_resolve_events()
	return result

func use_hitter() -> Dictionary:
	if not _can_act(): return {"ok":false,"reason":"wrong_mode"}
	var result: Dictionary = memory.use_hitter()
	_resolve_events()
	return result

func stamp_route() -> bool:
	var stop: Dictionary = progression.current_stop()
	if stop.is_empty(): return false
	var result: bool = progression.stamp_route({"reachable":_reachable("route:"+str(stop.id))})
	_resolve_events()
	return result

func _profile_stage(key: String,started: int) -> int:
	if not profile_enabled: return 0
	var now: int = Time.get_ticks_usec()
	profile_us[key] = int(profile_us.get(key,0))+now-started
	profile_calls[key] = int(profile_calls.get(key,0))+1
	return now

func advance(seconds: float, context: Dictionary = {}) -> bool:
	profile_us.clear()
	profile_calls.clear()
	if director != null:
		director.profile_enabled = profile_enabled; director.profile_us.clear()
	last_advanced_ms = 0.0
	if not is_finite(seconds) or seconds <= 0.0 or seconds > 240.0: return false
	if context.has("input_vector") and (not context.input_vector is Vector2 or not context.input_vector.is_finite()): return false
	_guard_cooking_transition()
	if s.mode == "cookmini":
		var frame_step: float = minf(seconds*1000.0,50.0)
		if float(s.get("hitPause",0)) > 0: s.hitPause = maxf(0,float(s.hitPause)-frame_step)
		else: cooking.tick(frame_step)
		_resolve_events(); _apply_pending_lifecycle(); _release_transitions(); _resolve_events()
		return true
	if s.mode != "playing": return true
	var remaining: float = seconds*1000.0
	while remaining > 0.000001 and s.mode == "playing":
		var step: float = minf(STEP_MS,remaining)
		remaining -= step
		_elapsed_ms += step
		if float(s.get("hitPause",0)) > 0:
			s.hitPause = maxf(0.0,float(s.hitPause)-step)
			continue # Source update() skips the whole step that began in hitpause.
		last_advanced_ms += step
		var profile_mark: int = Time.get_ticks_usec() if profile_enabled else 0
		var body_context: Dictionary = _move_player(step,context)
		profile_mark = _profile_stage("movement",profile_mark)
		memory.sync_visit()
		if not state.tick(step/1000.0,body_context): return false
		utilities.tick_squint(step,context.get("squint_held",false))
		_resolve_events()
		_tick_ambient_phone(step)
		s.hustleCheckT = float(s.get("hustleCheckT",0))+step
		if float(s.hustleCheckT) > 800:
			s.hustleCheckT = 0.0; progression.check_hustles()
		_tick_incidents(step)
		_tick_random_events(step)
		if interactive_props != null:
			interactive_props.tick(step); _sync_interactive_props()
		profile_mark = _profile_stage("state_ambient",profile_mark)
		if _actors_enabled:
			combat.tick_status(step)
			combat.tick_police(step,_wall_ms)
			bosses.tick_before_actors(step)
			kingdom.tick_active(step)
		profile_mark = _profile_stage("combat_timers",profile_mark)
		world_props.tick_props(step)
		progression.tick_territory(step,float(context.get("monotonic_ms",_elapsed_ms)))
		var border_zone: Dictionary = progression.current_zone() if s.get("lastZoneId") != s.get("territoryZoneId") else {}
		var border_patch: Dictionary = DistrictBorder.advance(s,s.get("territoryZoneId"),border_zone,step)
		for key: String in border_patch: s[key] = border_patch[key]
		utilities.tick_zone_entries()
		world_props.tick_bench(step)
		if days_enabled: days.tick_active(step)
		world_props.tick_phone(step)
		if _actors_enabled: director.tick_dog_discomfort()
		memory.tick(step)
		companions.tick_world(step)
		ambient_audio.tick_active(step)
		profile_mark = _profile_stage("memory_day_territory",profile_mark)
		quests.tick_before_pickups(step)
		_auto_collect()
		var automatic_menu: Dictionary = quests.tick_after_pickups()
		if not automatic_menu.is_empty():
			vendors.session.close(); travel.session.close(); residents.session.close()
			state.emit_event("dialogue_requested",{"domain":"quest","menu":automatic_menu})
		for actor: Dictionary in state.npcs:
			if actor.id == "pete": actor.shopClosed = float(s.dayTime) < 0.25 or float(s.dayTime) > 0.75; break
		profile_mark = _profile_stage("quests_pickups",profile_mark)
		if _actors_enabled:
			director.tick(step,_wall_ms)
			profile_mark = _profile_stage("actors",profile_mark)
			if profile_enabled:
				for key: String in director.profile_us: profile_us["actor_"+key] = director.profile_us[key]
		_drain_feedback_metadata()
		if _feedback_is_bound(): feedback.advance_particles(step)
		profile_mark = _profile_stage("world_feedback",profile_mark)
		if _actors_enabled:
			combat.tick_projectiles(step)
			bosses.tick_after_actors(step,_wall_ms)
			_resolve_events()
		profile_mark = _profile_stage("projectiles_boss",profile_mark)
		try_intro_remember()
		progression.update_ranks()
		heists.sync_rank_unlock()
		s.shake = Feedback.decayed_shake(s.get("shake",0),step)
		utilities.finish_world_step(step)
		_resolve_events()
		_profile_stage("progression",profile_mark)
	return true

func _tick_ambient_phone(step_ms: float) -> void:
	var intro: bool = not s.flags.get("introDone",false)
	var silence: bool = communications.silence_active()
	var timer: float = float(s.get("phoneT",0))
	s.phoneT = (timer if timer != 0 else 120000.0)-step_ms
	if s.phoneT <= 0:
		s.phoneT = 90000.0+state.random_float()*150000.0
		if not intro and not silence and state.random_float() < 0.8: communications.ring_phone()
	if not s.flags.get("momIntroFired",false):
		s.momTipT = float(s.get("momTipT",30000.0))-step_ms if s.get("momTipT") != null else 30000.0-step_ms
		if s.momTipT <= 0: communications.fire_mom_intro_once()

func _tick_random_events(step_ms: float) -> void:
	var timer: float = float(s.get("eventT",0))
	s.eventT = (timer if timer != 0 else 15000.0)-step_ms
	if s.eventT <= 0:
		s.eventT = 15000.0+state.random_float()*20000.0
		if s.flags.get("introDone",false) and not communications.silence_active() and not s.get("incident"):
			communications.fire_random_event()

func _move_player(step_ms: float,context: Dictionary) -> Dictionary:
	if not context.has("input_vector"): return context
	var result: Dictionary = context.duplicate()
	var input: Vector2 = context.input_vector.limit_length(1.0)
	if float(p.stunT) > step_ms: input = Vector2.ZERO
	result.moving = input.length_squared() > 0.0
	result.sprinting = context.get("sprinting",false) == true and result.moving
	if not result.moving: return result
	var speed: float = float(p.speed)
	if float(p.rockedT) > 0: speed *= 1.8
	if float(p.crashT) > 0: speed *= 0.5
	if float(p.slowT) > step_ms: speed *= 0.5
	if result.sprinting: speed *= 1.7
	var intended: Vector2 = Vector2(float(p.x),float(p.y))+input*speed*(step_ms/16.0)
	var bounds: Dictionary = state.content.world.bounds
	intended = intended.clamp(Vector2.ZERO,Vector2(float(bounds.w)-float(p.w),float(bounds.h)-float(p.h)))
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	if adapter == null or not adapter.has_method(&"move_body"): return result
	var body := {"id":"player","x":p.x,"y":p.y,"w":p.w,"h":p.h}
	var moved: Variant = adapter.call(&"move_body",body,intended)
	if moved is Dictionary and moved.get("position") is Vector2 and moved.position.is_finite():
		var at: Vector2 = moved.position
		if at.x >= 0 and at.y >= 0 and at.x+float(p.w) <= float(bounds.w) and at.y+float(p.h) <= float(bounds.h):
			p.x = at.x; p.y = at.y
	if absf(input.x) > absf(input.y): p.facing = "right" if input.x > 0 else "left"
	else: p.facing = "down" if input.y > 0 else "up"
	return result

func _auto_collect() -> void:
	for pile: Dictionary in state.cash_piles:
		if pile.get("collected",false) == true: continue
		if state.player_center().distance_squared_to(Vector2(pile.x,pile.y)) < 196.0:
			collect_cash(str(pile.id))

func collect_cash(id: String) -> bool:
	if s.mode != "playing": return false
	var pile: Dictionary = {}
	for candidate: Dictionary in state.cash_piles:
		if candidate.get("id") == id: pile = candidate; break
	if pile.is_empty() or pile.get("collected",false) == true: return false
	if state.player_center().distance_squared_to(Vector2(pile.x,pile.y)) >= 196.0 or not _reachable("cash:"+id): return false
	pile.collected = true
	if not s.cashPilesCollected.has(id): s.cashPilesCollected.append(id)
	if pile.get("tool") == "propane_torch":
		if not inventory.owns_tool("propane_torch"):
			var displaced: Variant = state.equip_tool("propane_torch")
			state.emit_event("sound",{"id":"pickup"})
			_toast("+ a propane torch (dented)\n(equipped.)\nit doesn't care." + ("\nthe crowbar goes to pete's glass.\nyou cook now. you do not pry." if displaced != null else ""))
			_feed("picked up a torch. found it. don't ask.","@crackheadcent")
		state.emit_event("save_requested") # Persist consumed duplicates too; ownership must never resurrect them.
	elif pile.get("equip") is String and state.content.catalogs.equipment.has(pile.equip):
		var equipment: Dictionary = state.content.catalogs.equipment[pile.equip]
		p.equip[equipment.slot] = pile.equip
		state.apply_equip_stats()
		state.emit_event("sound",{"id":"coin"})
		_toast("+ " + str(equipment.n) + "\n(equipped.)")
		state.emit_event("save_requested")
	else:
		var amount: int = int(pile.get("amt",0))
		p.cash += amount
		state.emit_event("sound",{"id":"pickup"})
		if not s.flags.get("introDone",false): s.counters.introCashEarned = int(s.counters.get("introCashEarned",0))+amount
		if pile.get("isInheritance",false) == true:
			s.flags.day14Collected = true
			_toast("+ $%d\n\nyou don't recognize the bill.\nyou don't recognize the wallet.\nyou recognize the smell." % amount)
			_feed("someone came into money. someone always does.","@hardcandy")
			state.apply_rep({"street":2,"spiritual":-1})
		else:
			_toast("+ $%d\n%s" % [amount,"you bend down. the ten dollars is yours now.\n(it was always there.)" if pile.get("intro",false) == true else "(found in a corner.)"])
		try_intro_remember()
		state.emit_event("save_requested")
	state.emit_event("gesture",{"action":"pickup"})
	_resolve_events()
	return true

func try_intro_remember() -> bool:
	if s.flags.get("introDone",false): return false
	var quest: Dictionary = s.quests.get("intro_remember",{})
	if quest.is_empty() or quest.get("done",false): return false
	if int(p.cash) >= 10: s.counters.introCashEarned = maxi(10,int(s.counters.get("introCashEarned",0)))
	if int(s.counters.get("introCashEarned",0)) < 10: return false
	quest.done = true; p.cred += 1
	s.quests.intro_tony.available = true
	state.emit_event("quest_completed",{"id":"intro_remember"})
	_toast("you arrive somewhere by walking. who knew.")
	state.emit_event("save_requested")
	return true

func _resolve_events() -> void:
	# Domain consequences complete synchronously; the renderer never observes half a transaction.
	_guard_cooking_transition()
	while not state.events.is_empty():
		var batch: Array = state.drain_events()
		for event: Dictionary in batch:
			_feedback_event(event)
			match event.kind:
				"cart_changed":
					_sync_cart(); _outbox.append(event)
				"feed","news":
					communications.consume_event(event)
					_outbox.append(event)
				"save_requested": _save_wanted = true
				"delayed_toast":
					if _presentation_tasks.size() >= 32: _presentation_tasks.pop_front()
					_presentation_tasks.append({"due":_wall_ms+clampf(float(event.payload.get("delay_ms",0)),0,60000),"payload":{"text":str(event.payload.get("text","")),"duration_ms":event.payload.get("duration_ms",2200)},"player_epoch":p,"state_epoch":s})
				"intro_completed":
					progression.roll_hustles(); progression.roll_route()
					state.emit_event("news",{"text":"the neighborhood notices you arrived. the neighborhood does not care."})
					_feed("smoked one on the crate.\nthe sun moved.\nthe loop greeted me.","@crackheadcent")
					_outbox.append(event)
				"day_started":
					if not event.payload.get("handled",false):
						progression.roll_hustles()
						travel.on_natural_dawn()
					_outbox.append(event)
				"kingdom_changed":
					campaign.sync_quests(); _outbox.append(event)
				"kingdom_abort_requested":
					if kingdom != null: kingdom.abort(false,false)
				"kingdom_ending_due":
					if cooking.is_resolving():
						_defer_lifecycle("mode","ending"); _hold_transition(event); continue
					if kingdom != null and set_mode("ending"): kingdom.commit_ending()
				"death", "arrest":
					if not cooking.cancel(event.kind):
						_hold_transition(event)
						continue
					_death_cleanup(event.kind)
					_outbox.append(event)
				"ending_requested", "ending":
					if cooking.is_resolving():
						_defer_lifecycle("mode","title" if event.kind == "ending_requested" else "ending")
						_hold_transition(event)
						continue
					cooking.cancel("ending")
					_outbox.append(event)
				"faction_tier_changed":
					var lines: Array = Content.definition("src/systems/factions.js","TIER_TRANSITION_LINES",{}).get(event.payload.faction,{}).get(event.payload.after,[])
					if not lines.is_empty():
						var colon: int = str(lines[0]).find(": ")
						_feed(str(lines[0]).substr(colon+2),str(lines[0]).substr(0,colon))
						_toast(lines[1])
					_outbox.append(event)
				_: _outbox.append(event)

func drain_events() -> Array[Dictionary]:
	_resolve_events()
	var events: Array[Dictionary] = _outbox.duplicate(true)
	_outbox.clear()
	if _save_wanted and not cooking.is_resolving():
		events.append({"kind":"save_requested","payload":{"snapshot":state.snapshot()}})
		_save_wanted = false
	return events

func _toast(text: String) -> void: state.emit_event("toast",{"text":text})
func _feed(text: String, author: String) -> void: state.emit_event("feed",{"text":text,"author":author})

# Cosmetic metadata cursor. This observes no domain consequences and never drains events.
func set_feedback_context(right: Vector3) -> bool:
	if not right.is_finite() or not is_finite(right.length_squared()): return false
	var horizontal := Vector3(right.x,0,right.z)
	if horizontal.length_squared() < 0.000001: return false
	_feedback_right = horizontal.normalized()
	return true

func _feedback_reset(reason: String,bind_epoch: bool = false) -> void:
	_feedback_epoch += 1
	feedback.reset_epoch(_feedback_epoch)
	_feedback_stats.resets += 1
	_feedback_stats.last_reset = reason
	if bind_epoch:
		_feedback_player = p; _feedback_state = s; _feedback_bound = true

func _feedback_is_bound() -> bool:
	if not _feedback_bound: return false
	if not is_same(_feedback_player,p) or not is_same(_feedback_state,s):
		_feedback_bound = false
		_feedback_reset("unexpected_epoch")
		return false
	return true

func _feedback_event(event: Dictionary) -> void:
	if event.has("_world_feedback_cursor"): return
	var payload: Variant = event.get("payload",{})
	var lifecycle: bool = event.get("kind","") in ["death","arrest"]
	if not lifecycle and (not payload is Dictionary or not payload.has("feedback")): return
	_feedback_cursor += 1
	event["_world_feedback_cursor"] = _feedback_cursor
	if not _feedback_is_bound(): return
	if lifecycle: _feedback_reset(str(event.kind))
	if not payload is Dictionary or not payload.has("feedback"): return
	if not payload.feedback is Array:
		_feedback_stats.rejected += 1; return
	for raw: Variant in payload.feedback:
		if not raw is Dictionary:
			_feedback_stats.rejected += 1; continue
		var receipt: Dictionary = _feedback_anchors.decorate(raw,_feedback_right,_feedback_epoch)
		if receipt.is_empty() or not feedback.accept(receipt): _feedback_stats.rejected += 1
		else: _feedback_stats.accepted += 1

func _drain_feedback_metadata() -> void:
	_feedback_is_bound()
	for event: Dictionary in state.events: _feedback_event(event)

func feedback_snapshot() -> Dictionary:
	_feedback_is_bound()
	return feedback.snapshot()

func feedback_inspect() -> Dictionary:
	_feedback_is_bound()
	return {"epoch":_feedback_epoch,"bound":_feedback_bound,"cursor":_feedback_cursor,"bridge":_feedback_stats.duplicate(),"pool":feedback.inspect()}
