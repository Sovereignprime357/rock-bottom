class_name RockBottomHeists
extends RefCounted
## One data-driven site flow; the four-pin puzzle is an entry substate.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Lockpick = preload("res://scripts/lockpick_system.gd")
const MODULE := "src/minigames/activities.js"
const COPPER_IDS := ["abandoned","cold_not","water_dept","rust_car"]
const BREAKIN_IDS := ["model_home","spoil_bank","sod_office","drained_pool","visitor_center"]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var inventory: RefCounted
var _sites: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _abandoned_anchor: Dictionary = {}
var _abandoned_locked: bool = false
var _active: bool = false
var _site: Dictionary = {}
var _stage: String = ""
var _refusal: String = ""
var _refusal_label: String = "leave."
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _lock_entry: Dictionary = {}
var puzzle: RefCounted
var _lock_context: String = ""

func _init(owner: RefCounted,spatial: Object,shared_lockpick: RefCounted = null) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	session = Session.new(owner,self,&"_session_available")
	inventory = Inventory.new(owner)
	puzzle = shared_lockpick if shared_lockpick != null else Lockpick.new(owner)
	_lock_context = "heist:%d" % get_instance_id()
	for key: String in ["COPPER_SITES","BREAKIN_SITES"]:
		for row: Dictionary in owner.definition("src/data/props.js",key,[]):
			var site: Dictionary = row.duplicate(true)
			_sites.append(site); _by_id[str(site.id)] = site
	for building: Dictionary in owner.content.get("buildings",[]):
		if building.get("locked",false) == true:
			_abandoned_anchor = building.duplicate(true); _abandoned_locked = true; break
func ready() -> bool:
	if host == null or _sites.size() != 9 or _by_id.size() != 9 or _abandoned_anchor.is_empty(): return false
	for id: String in COPPER_IDS+BREAKIN_IDS:
		if not _by_id.has(id): return false
	return true
func supports(id: String) -> bool: return _by_id.has(id)
func site_available(id: String) -> bool: return supports(id) and (id != "abandoned" or _abandoned_locked)
func sync_rank_unlock() -> void:
	if host != null and _abandoned_locked and int(host.p.rank) >= 4:
		_abandoned_locked = false
		host.emit_event("site_availability_changed",{"id":"abandoned","target":"copper:abandoned","available":false,"boarded":false})
func _anchor(site: Dictionary) -> Dictionary:
	return _abandoned_anchor if site.id == "abandoned" else site.anchor
func _inside(site: Dictionary,center: Vector2) -> bool:
	if not center.is_finite(): return false
	var rect: Dictionary = _anchor(site)
	return center.x > rect.x-20 and center.x < rect.x+rect.w+20 and center.y > rect.y-20 and center.y < rect.y+rect.h+20
func site_at(center: Vector2) -> String:
	if not ready(): return ""
	for site: Dictionary in _sites:
		if site_available(site.id) and _inside(site,center): return site.id
	return ""
func _target_id(site: Dictionary) -> String: return ("breakin:" if site.has("loot") else "copper:")+str(site.id)
func _same_epoch() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func is_active() -> bool: return _active and _same_epoch()
func _session_available(target: String) -> bool:
	return is_active() and host.s.mode == "dialogue" and not _site.is_empty() and target == _target_id(_site) and (_stage != "lock" or puzzle.active(_lock_context))
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _constant(key: String) -> int: return int(host.definition(MODULE,key,0))
func _gate(site: Dictionary) -> String:
	for gate: Dictionary in site.get("gates",[]):
		if gate.kind == "tool" and host.p.equip.get("tool") != gate.tool: return gate.refuse
		if gate.kind == "cred" and host.p.cred < gate.cred: return gate.refuse
	return ""
func open(id: String) -> Dictionary:
	if not ready(): return _fail("missing_content")
	if is_active(): return _fail("activity_active")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	if not site_available(id): return _fail("site_unavailable")
	var site: Dictionary = _by_id[id]
	if not _inside(site,host.player_center()): return _fail("out_of_reach")
	var spatial: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if spatial == null or not spatial.has_method(&"can_use_site"): return _fail("missing_spatial_adapter")
	if spatial.call(&"can_use_site",_target_id(site)) != true: return _fail("out_of_reach")
	close()
	_player_epoch = host.p; _state_epoch = host.s; _active = true; _site = site
	_refusal = _gate(site); _refusal_label = "leave."
	if not _refusal.is_empty(): _stage = "refused"; return _menu()
	var counter: String = "breakinsToday" if site.has("loot") else "heistsToday"
	var cap: int = _constant("BREAKIN_DAILY_CAP" if site.has("loot") else "HEIST_DAILY_CAP")
	if int(host.s.counters.get(counter,0)) >= cap:
		_stage = "refused"; _refusal = site.capText; _refusal_label = "come back tomorrow."; return _menu()
	host.s.counters[counter] = int(host.s.counters.get(counter,0))+1
	_stage = "entry"
	return _menu()
func _option(id: String,label: String,enabled: bool = true) -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else "unavailable"}
func _options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	match _stage:
		"refused": options.append(_option("leave",_refusal_label))
		"entry":
			for index: int in range(_site.entries.size()):
				var entry: Dictionary = _site.entries[index]
				var enabled: bool = true
				var label: String = str(entry.get("label",""))
				if entry.kind == "item":
					enabled = inventory.count_records(entry.itemId) > 0
					label = entry.haveLabel if enabled else entry.lackLabel
				elif entry.kind == "cash":
					enabled = host.p.cash >= entry.cost
					label = entry.haveLabel if enabled else entry.lackLabel
				options.append(_option("entry:%d" % index,label,enabled))
			options.append(_option("leave","leave."))
		"take":
			options.append(_option("take",_site.loot.takeLabel if _site.has("loot") else "strip them."))
			options.append(_option("listen",_site.loot.altLabel if _site.has("loot") else "listen to them sing."))
			options.append(_option("leave","leave."))
		"exit":
			for index: int in range(_site.exits.size()): options.append(_option("exit:%d" % index,_site.exits[index].label))
		"lock":
			for pin: int in range(1,5): options.append(_option("pin:%d" % pin,"%d. set pin %d" % [pin,pin]))
			options.append(_option("give_up","give up."))
	return options
func _menu() -> Dictionary:
	var title: String = str(_site.title)
	var text: String = ""
	match _stage:
		"refused": text = _refusal
		"entry": text = _site.intro
		"take":
			title = _site.loot.title if _site.has("loot") else "THE COPPER PIPES"
			text = _site.loot.text if _site.has("loot") else _site.pipes.text
		"exit": title = "GETAWAY"; text = _site.getawayText
		"lock":
			var view: Dictionary = puzzle.snapshot(_lock_context)
			if view.is_empty(): close(); return _fail("stale_puzzle")
			title = view.title; text = view.text
	var options: Array[Dictionary] = _options()
	var actions: Array[String] = []
	for option: Dictionary in options: actions.append(option.id)
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin(_target_id(_site),actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"heist","token":opened.token,"actor":_target_id(_site),"title":title,"text":text,"options":options}
func _effects(effect: Dictionary) -> void:
	if effect.has("text"): _toast(effect.text,int(effect.get("dur",2200)))
	if effect.has("hp"): host.p.hp -= effect.hp
	if effect.get("glass",false): _sound("glassBreak")
	if effect.has("wanted"): host.p.wanted = minf(3,host.p.wanted+effect.wanted)
	if effect.has("brain"): host.p.brain = maxf(0,host.p.brain-effect.brain)
	if effect.has("shakes"): host.p.shakes = minf(100,host.p.shakes+effect.shakes)
func _advance_entry() -> Dictionary:
	if host.p.hp <= 0:
		close(); host.die(); return {"ok":true,"closed":true,"died":true}
	_stage = "take"; return _menu()
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	var enabled: bool = false
	for option: Dictionary in _options():
		if option.id == action: enabled = option.enabled; break
	if not enabled: close(); return _fail("action_unavailable")
	# The source closes dialogue before running each option callback.
	host.s.mode = "playing"
	if action == "leave": close(); return {"ok":true,"closed":true}
	match _stage:
		"entry":
			var entry: Dictionary = _site.entries[int(action.get_slice(":",1))]
			match entry.kind:
				"roll": _effects(entry.under if host.random_float() < entry.p else entry.over)
				"lockpick":
					_lock_entry = entry; puzzle.begin(_lock_context); _stage = "lock"; return _menu()
				"item":
					if entry.get("consume") == "one": inventory.remove_first_record(entry.itemId)
					else: inventory.remove_all(entry.itemId)
					_effects(entry.effect)
				"cash": host.p.cash -= entry.cost; _effects(entry.effect)
				"wait","sure": _effects(entry.effect)
			return _advance_entry()
		"take":
			if _site.has("loot"):
				var loot: Dictionary = _site.loot
				if action == "take":
					host.p.cash += loot.get("cash",0)
					for item: Dictionary in loot.get("items",[]): inventory.append_item(item.id,item.n)
					_sound("pickup"); _toast(loot.takeToast,int(loot.takeDur))
				else:
					if loot.alt.has("brain"): host.p.brain = minf(100,host.p.brain+loot.alt.brain)
					_toast(loot.alt.text,int(loot.alt.dur))
			elif action == "take":
				var got: int = _constant("HEIST_YIELD_MIN")+host.random_index(_constant("HEIST_YIELD_SPAN"))
				host.p.copper += got; _sound("glassBreak")
				host.s.counters.copperStripped += got
				if host.s.counters.copperStripped >= 10: host.unlock_achievement("copper_singer")
				_toast("+ %d pure copper\n" % got+str(_site.pipes.stripAfter))
				if not host.s.quests.copper_sings.done:
					host.s.quests.copper_sings.done = true
					_toast("· QUEST COMPLETE ·\nTHE COPPER SINGS"); _sound("rankUp")
			else:
				host.p.brain = minf(100,host.p.brain+8); _toast("+ 8 brain\n"+str(_site.pipes.listenAfter))
			_stage = "exit"; return _menu()
		"exit":
			var exit: Dictionary = _site.exits[int(action.get_slice(":",1))]
			_effects(exit.under if host.random_float() < exit.p else exit.over)
			close()
			if host.p.hp <= 0: host.die()
			host.s.mode = "playing"; host.emit_event("save_requested")
			return {"ok":true,"closed":true}
		"lock":
			if action == "give_up":
				puzzle.cancel(_lock_context)
				_effects(_lock_entry.fail)
				if _lock_entry.fail.has("extra") and host.random_float() < _lock_entry.fail.extraChance: _effects(_lock_entry.fail.extra)
				return _advance_entry()
			var pin: int = int(action.get_slice(":",1))
			var picked: Dictionary = puzzle.choose(_lock_context,pin)
			if not picked.ok: close(); return picked
			if picked.complete: _effects(_lock_entry.ok); return _advance_entry()
			return _menu()
	close(); return _fail("invalid_stage")
func close() -> void:
	if is_active() and (_stage != "lock" or puzzle.active(_lock_context)) and host.s.mode in ["dialogue","heist"]: host.s.mode = "playing"
	session.close(); _active = false; _site = {}; _stage = ""; _refusal = ""; _lock_entry = {}
	puzzle.cancel(_lock_context); _player_epoch = {}; _state_epoch = {}
