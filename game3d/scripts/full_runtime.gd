class_name RockBottomRuntime
extends RefCounted
## Single full-model composition. Presentation and IO consume events after committed commands.
const State = preload("res://scripts/game_state.gd")
const Memory = preload("res://scripts/memory_loop.gd")
const Progression = preload("res://scripts/progression_routes.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Vendors = preload("res://scripts/vendors_core.gd")
const Content = preload("res://scripts/content_catalog.gd")
const STEP_MS := 1000.0 / 60.0
var state: RefCounted
var memory: RefCounted
var progression: RefCounted
var inventory: RefCounted
var vendors: RefCounted
var _spatial: WeakRef
var _outbox: Array[Dictionary] = []
var _save_wanted: bool = false
var _elapsed_ms: float = 0.0
var p: Dictionary:
	get: return state.p
var s: Dictionary:
	get: return state.s

func _init(spatial_adapter: Object, boss_adapter: Object = null) -> void:
	_spatial = weakref(spatial_adapter) if spatial_adapter != null else null
	state = State.new()
	memory = Memory.new(state)
	progression = Progression.new(state)
	inventory = Inventory.new(state)
	vendors = Vendors.new(state,spatial_adapter,memory,boss_adapter)
	s.mode = "title"
	state.drain_events()

func _reachable(id: String) -> bool:
	var adapter: Object = _spatial.get_ref() if _spatial != null else null
	return adapter != null and adapter.has_method(&"can_reach_target") and adapter.call(&"can_reach_target",id) == true

func fresh() -> bool:
	vendors.session.close()
	_outbox.clear(); _save_wanted = false; _elapsed_ms = 0.0
	if not state.fresh(): return false
	s.mode = "playing"
	memory.normalize_state()
	state.emit_event("placement_reset",{"source_position":state.player_center(),"reason":"fresh"})
	return true

func restore(data: Variant) -> bool:
	if not data is Dictionary: return false
	# The low-level codec returns fresh defaults on a rejected envelope. The live controller
	# validates that envelope first so a bad file cannot erase the current play session.
	var schema: Variant = data.get("schema")
	if not (schema is int or schema is float) or not is_finite(float(schema)): return false
	if schema != 1 and schema != 2: return false
	if schema == 2 and (data.get("format") != State.SAVE_FORMAT or not data.get("player") is Dictionary or not data.get("state") is Dictionary): return false
	var restored: Dictionary = state.restore(data)
	if restored.get("ok") != true: return false
	vendors.session.close()
	_outbox.clear(); _save_wanted = false; _elapsed_ms = 0.0
	s.mode = "playing"
	progression.ensure_route()
	state.emit_event("placement_reset",{"source_position":state.player_center(),"reason":"restore"})
	return true

func snapshot() -> Dictionary: return state.snapshot()

func set_mode(mode: String) -> bool:
	if mode not in ["title","playing","paused","dialogue","cookmini","heist","ending"]: return false
	if mode != "dialogue": vendors.session.close()
	s.mode = mode
	return true

func close_dialogue() -> void:
	vendors.session.close()
	if s.mode == "dialogue": s.mode = "playing"

func open_vendor(id: String) -> Dictionary:
	var result: Dictionary = vendors.open(id)
	_resolve_events()
	return result

func select_vendor(token: Variant, action: String) -> Dictionary:
	var result: Dictionary = vendors.select(token,action)
	try_intro_remember()
	_resolve_events()
	return result

func _can_act() -> bool:
	return s.mode in ["playing","dialogue"] and float(p.stunT) <= 0.0

func smoke(spot_id: String) -> Dictionary:
	if not _can_act() or not _reachable("smoke:"+spot_id): return {"ok":false,"reason":"unreachable"}
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

func advance(seconds: float, context: Dictionary = {}) -> bool:
	if not is_finite(seconds) or seconds <= 0.0 or seconds > 240.0: return false
	if context.has("input_vector") and (not context.input_vector is Vector2 or not context.input_vector.is_finite()): return false
	if s.mode != "playing": return true
	var remaining: float = seconds*1000.0
	while remaining > 0.000001 and s.mode == "playing":
		var step: float = minf(STEP_MS,remaining)
		remaining -= step
		_elapsed_ms += step
		if float(s.get("hitPause",0)) > 0:
			s.hitPause = maxf(0.0,float(s.hitPause)-step)
			continue # Source update() skips the whole step that began in hitpause.
		var body_context: Dictionary = _move_player(step,context)
		memory.sync_visit()
		if not state.tick(step/1000.0,body_context): return false
		_resolve_events()
		progression.tick_territory(step,float(context.get("monotonic_ms",_elapsed_ms)))
		memory.tick(step)
		_auto_collect()
		try_intro_remember()
		s.hustleCheckT = float(s.get("hustleCheckT",0))+step
		if float(s.hustleCheckT) > 800:
			s.hustleCheckT = 0.0; progression.check_hustles()
		progression.update_ranks()
		_resolve_events()
	return true

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
	while not state.events.is_empty():
		var batch: Array = state.drain_events()
		for event: Dictionary in batch:
			match event.kind:
				"save_requested": _save_wanted = true
				"intro_completed":
					progression.roll_hustles(); progression.roll_route()
					state.emit_event("news",{"text":"the neighborhood notices you arrived. the neighborhood does not care."})
					_feed("smoked one on the crate.\nthe sun moved.\nthe loop greeted me.","@crackheadcent")
					_outbox.append(event)
				"day_started":
					progression.roll_hustles()
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
	if _save_wanted:
		events.append({"kind":"save_requested","payload":{"snapshot":state.snapshot()}})
		_save_wanted = false
	return events

func _toast(text: String) -> void: state.emit_event("toast",{"text":text})
func _feed(text: String, author: String) -> void: state.emit_event("feed",{"text":text,"author":author})
