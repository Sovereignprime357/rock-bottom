extends RefCounted
## Commands over shared source PROPS; Runtime owns scheduling and input.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const BENCH_KEYS := ["sittingOnBench","benchSitT","benchSitGainT","benchSitPasserT"]
const PHONE_KEYS := ["publicPhoneT","phonePropRingT"]
const PASSERS := [
	"the philosopher said you'd be here.\nshe was right.",
	"a pigeon walks past.\nit nods.\nyou nod.",
	"a jogger passes.\nshe is talking on the phone.\nshe is talking about you.",
	"the fountain coughs.\nthe fountain continues.",
	"you have been here a while.\nthe bench has been here longer."]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _props_ref: WeakRef
var _memory_ref: WeakRef
var _companions_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var inventory: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _menu_player: Dictionary = {}
var _menu_state: Dictionary = {}
var _menu_target: String = ""
var _offers: Array[Dictionary] = []
var _pool: Array[Dictionary] = []
var _phones: Array[Dictionary] = []
var _dumpster_ids: Array[String] = []
var _interaction_ids: Dictionary = {}
var _pending_phone: Dictionary = {}
var _phone_retry_ms: float = 0.0
var _handoff: Dictionary = {}
var _serial: int = 0
var _item_id: RegEx

func _init(owner: RefCounted,spatial: Object,props: RefCounted,memory: RefCounted,companions: RefCounted) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	_props_ref = weakref(props) if props != null else null
	_memory_ref = weakref(memory) if memory != null else null
	_companions_ref = weakref(companions) if companions != null else null
	session = Session.new(owner,self,&"_session_available"); inventory = Inventory.new(owner)
	_item_id = RegEx.new(); _item_id.compile("[^A-Za-z0-9_]")
	for item: Dictionary in owner.content.catalogs.get("itemLoot",[]):
		var sources: Array = item.get("sources",[])
		if not sources.is_empty() and sources[0].get("kind") == "dumpster_pool":
			var row: Dictionary = {}
			for key: String in ["n","q","heal","val","id","what"]:
				if item.has(key): row[key] = item[key]
			_pool.append(row)
	for line: Dictionary in owner.content.catalogs.get("publicPhoneLines",[]): _phones.append(line.duplicate(true))
	if companions != null and companions.has_method(&"set_dumpster_authority"): companions.set_dumpster_authority(self)
	reset_session("cold")

func _object(reference: WeakRef,method: StringName) -> Object:
	var object: Object = reference.get_ref() if reference != null else null
	return object if object != null and object.has_method(method) else null
func _same_epoch() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func ready() -> bool:
	var props: Object = _object(_props_ref,&"ready")
	var memory: Object = _object(_memory_ref,&"dumpster_hitter_roll")
	var companions: Object = _object(_companions_ref,&"open_from_dumpster")
	return _same_epoch() and _pool.size() == 22 and _phones.size() == 10 and props != null and props.ready() == true and memory != null and memory.has_method(&"grant_found_hitter") and memory.has_method(&"record") and companions != null and companions.has_method(&"ready") and companions.ready() == true
func reset_session(reason: String) -> bool:
	if host == null or reason not in ["cold","fresh","restore"]: return false
	var old_state: Dictionary = _state_epoch
	close(); _pending_phone.clear(); _phone_retry_ms = 0.0; _handoff.clear()
	if reason != "cold" and not old_state.is_empty():
		for key: String in BENCH_KEYS:
			if old_state.has(key): host.s[key] = old_state[key]
		if reason == "restore":
			for key: String in PHONE_KEYS:
				if old_state.has(key): host.s[key] = old_state[key]
	if reason == "fresh":
		host.s.publicPhoneT = 240000.0+host.random_float()*240000.0
		host.s.phonePropRingT = 0.0; host.s.publicPhoneAnswered = 0
	_player_epoch = host.p; _state_epoch = host.s
	_dumpster_ids.clear(); _interaction_ids = {"park_bench":[],"pay_phone":[],"dumpster":[]}
	var props: Object = _object(_props_ref,&"record")
	if props != null:
		for index: int in range(host.content.props.size()):
			var id := "prop:%d" % index
			var row: Dictionary = props.record(id)
			if row.get("type") == "dumpster": _dumpster_ids.append(id)
			if _interaction_ids.has(row.get("type")): _interaction_ids[row.type].append(id)
	return ready()
func interaction_ids(kind: String) -> Array:
	return _interaction_ids.get(kind,[]).duplicate() if _same_epoch() else []
func _prop(id: String) -> Dictionary:
	var props: Object = _object(_props_ref,&"record")
	return props.record(id) if props != null else {}
func supports(id: String) -> bool: return _prop(id).get("type") in ["park_bench","dumpster","pay_phone"]
func _reason(id: String) -> String:
	if not ready(): return "missing_dependency"
	var prop: Dictionary = _prop(id)
	if prop.get("type") not in ["park_bench","dumpster","pay_phone"]: return "unknown_prop"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	var center := Vector2(prop.x,prop.y)
	var radius: float = 38.0
	if prop.type != "pay_phone":
		center += Vector2(prop.w,prop.h)*0.5
		radius = 50.0 if prop.type == "park_bench" else 44.0
	if host.player_center().distance_squared_to(center) >= radius*radius: return "out_of_reach"
	var spatial: Object = _object(_spatial_ref,&"can_reach_target")
	if spatial == null: return "missing_spatial_adapter"
	if spatial.call(&"can_reach_target",id) != true: return "out_of_reach"
	return ""
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _feed(text: String,author: String = "@crackheadcent") -> void: host.emit_event("feed",{"text":text,"author":author})
func _save() -> void: host.emit_event("save_requested")
func _gesture(action: String = "interact") -> void: host.emit_event("gesture",{"action":action})

func open(id: String) -> Dictionary:
	var reason := _reason(id)
	if not reason.is_empty(): return _fail(reason)
	var prop: Dictionary = _prop(id)
	if prop.type == "park_bench": return _bench()
	if prop.type == "pay_phone": return _answer_phone()
	if prop.get("looted",false):
		_toast("the dumpster is empty.\nyou look anyway.",1500)
		return {"ok":true,"closed":true,"committed":false}
	close()
	if prop.get("tipsJar",false):
		prop.tipsJar = false; host.p.cash += 8+host.random_index(7); _sound("coin")
		_toast("there's a 'TIPS' jar duct-taped to the dumpster.\nit has cash in it.\n+ $%d\n(then there's the rest of the dumpster.)" % (8+host.random_index(7)),3000)
	_offers = _draw_offers(prop)
	_menu_player = host.p; _menu_state = host.s; _menu_target = id
	var options: Array[Dictionary] = []
	var actions: Array[String] = []
	for index: int in range(_offers.size()):
		var item: Dictionary = _offers[index]
		var suffix: String = {"sell":" (sell)","eat":" (eat)","cash":" (take)","equip":" (wear)"}.get(item.q,"")
		var action := "take:%d" % index
		options.append({"id":action,"label":str(item.n)+suffix,"enabled":true,"reason":""}); actions.append(action)
	options.append({"id":"leave","label":"climb out.","enabled":true,"reason":""}); actions.append("leave")
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin(id,actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"world_props","token":opened.token,"actor":id,"title":"THE DUMPSTER","text":"you are inside a dumpster.\nyou find three things.\nyou can take one.","options":options}

func _draw_offers(prop: Dictionary) -> Array[Dictionary]:
	# Loot thresholds use source doubles; Vector2 is float32 in this build.
	var dx: float = float(prop.x)-1050.0
	var dy: float = float(prop.y)-840.0
	var far := minf(1.0,sqrt(dx*dx+dy*dy)/900.0)
	var roll: float = host.random_float()
	var none_cut := 0.30+(1.0-far)*0.20
	var memory: Object = _memory_ref.get_ref()
	var picked: Dictionary
	if memory.dumpster_hitter_roll(far): picked = {"n":"the emergency hitter","q":"hitter_drop"}
	elif roll < none_cut: picked = {"n":"nothing. dumpsters know.","q":"rats"}
	elif roll < none_cut+0.30:
		picked = {"n":"$%d in loose bills" % (1+host.random_index(4)),"q":"cash","val":1+host.random_index(4)}
	elif roll < none_cut+0.50: picked = {"n":"a piece of junk (sells $1)","q":"junkdrop"}
	elif roll < none_cut+0.60: picked = {"n":"a clean packet of supply","q":"clean_packet"}
	elif roll < none_cut+0.68: picked = {"n":"a broken bottle (weapon)","q":"bb_weapon"}
	elif far > 0.6 and host.p.equip.get("tool") != "propane_torch" and not host.s.flags.get("dumpsterPropaneAwarded",false) and host.random_float() < 0.07:
		picked = {"n":"a propane torch (dented)","q":"torch_drop"}
	else: picked = _pool[host.random_index(_pool.size())].duplicate(true)
	return [_pool[host.random_index(_pool.size())].duplicate(true),_pool[host.random_index(_pool.size())].duplicate(true),picked]

func _menu_active() -> bool:
	return not _menu_target.is_empty() and host != null and is_same(_menu_player,host.p) and is_same(_menu_state,host.s)
func _session_available(id: String) -> bool:
	return ready() and _menu_active() and host.s.mode == "dialogue" and id == _menu_target and _prop(id).get("type") == "dumpster"
func close() -> void:
	if _menu_active() and host.s.mode == "dialogue": host.s.mode = "playing"
	if session != null: session.close()
	_menu_target = ""; _offers.clear(); _menu_player = {}; _menu_state = {}
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	var id: String = _menu_target
	var item: Dictionary = {} if action == "leave" else _offers[int(action.get_slice(":",1))].duplicate(true)
	close()
	var props: Object = _props_ref.get_ref()
	if action == "leave":
		props.set_dumpster_looted(id,true)
		_toast("you climb out.\nno one saw.\n(some saw.)")
		_gesture("dumpster")
		return {"ok":true,"closed":true,"committed":true}
	_apply_loot(item,id)
	props.set_dumpster_looted(id,true); _prop(id).diveCdT = 90000.0
	host.s.counters.dumpDives = int(host.s.counters.get("dumpDives",0))+1
	_save()
	if item.q == "event" and item.get("what") == "possum":
		_serial += 1
		var ticket := "%d:dumpster:%d" % [get_instance_id(),_serial]
		_handoff = {"ticket":ticket,"player":host.p,"state":host.s}
		var companion: Object = _companions_ref.get_ref()
		var menu: Dictionary = companion.open_from_dumpster(ticket)
		_handoff.clear()
		return menu
	_gesture("eat" if item.q == "eat" else "dumpster")
	return {"ok":true,"closed":true,"committed":true}
func consume_possum_handoff(ticket: Variant) -> bool:
	if not ticket is String or _handoff.is_empty() or ticket != _handoff.ticket: return false
	var valid: bool = _same_epoch() and is_same(_handoff.player,host.p) and is_same(_handoff.state,host.s)
	_handoff.clear()
	return valid

func _apply_loot(item: Dictionary,id: String) -> void:
	match str(item.q):
		"eat":
			host.p.hp = minf(host.p.maxHp,host.p.hp+float(item.get("heal",5)))
			_toast("+ %d hp\n(it tastes like the dumpster.)" % int(item.get("heal",0)))
		"sell","cash":
			var value: int = int(item.get("val",0))
			if item.q == "sell" and value == 0: value = 3+host.random_index(4)
			host.p.cash += value
			if item.q == "cash": _sound("coin")
			_toast("+ $%d\n(%s.)" % [value,item.n])
			if item.q == "sell": _sound("coin")
		"item":
			inventory.append_item(str(item.get("id",_item_id.sub(item.n,"",true))),item.n)
			_toast("+ "+str(item.n))
		"equip":
			var equipment: Dictionary = host.content.catalogs.equipment[item.id]
			host.p.equip[equipment.slot] = item.id; host.apply_equip_stats()
			_toast("+ EQUIPPED · "+str(equipment.n))
		"event": _toast("a possum.\nhe is annoyed.\nhe leaves through the lid.")
		"rats":
			_toast("the rats are upset.\nthey have lives.",2000)
			host.emit_event("prop_effect",{"id":id,"kind":"rats","count":10})
		"junkdrop":
			inventory.append_item("junk","a piece of junk")
			_toast("+ a piece of junk.\n(pete will take it. for one dollar.)",2200)
		"clean_packet":
			host.p.supplies += 1; _toast("+ a clean packet.\n(unmarked. you take it. you don't ask.)",2400); _sound("coin")
		"bb_weapon":
			host.p.weapon = "broken_bottle"
			var name: String = host.content.catalogs.weapons.broken_bottle.n
			_toast("+ "+name+"\n(equipped.)"); _feed("picked up "+name+". things are escalating.")
			_toast("+ a broken bottle.\nit cuts. you understand this.\n(weapon equipped.)",2600)
		"torch_drop":
			if host.p.equip.get("tool") != "propane_torch":
				host.p.equip.tool = "propane_torch"; host.apply_equip_stats(); host.s.flags.dumpsterPropaneAwarded = true
				_toast("+ a propane torch (dented).\nsomebody buried this.\n(equipped.)",4400)
				_feed("found a torch in a dumpster. the dumpster knew.")
			else: _toast("a torch. you already have one.\nyou close the lid.",2000)
		"hitter_drop": (_memory_ref.get_ref() as Object).grant_found_hitter()

func _bench() -> Dictionary:
	if host.s.get("sittingOnBench",false):
		var sat: float = float(host.s.get("benchSitT",0))
		host.s.sittingOnBench = false; host.s.benchSitT = 0.0
		_toast("you stand up.\nthe bench remembers.\n(sat for %d seconds.)" % int(floor(sat/1000.0)),2400)
	else:
		host.s.sittingOnBench = true
		(_memory_ref.get_ref() as Object).record("park","sit","park_bench")
		host.s.benchSitT = 0.0; host.s.benchSitGainT = 0.0; host.s.benchSitPasserT = 0.0
		_toast("you sit.\nthe pigeons consider you furniture.\nE to stand.",2400)
	_gesture("bench")
	return {"ok":true,"closed":true,"committed":true}
func _valid_step(dt: float) -> bool: return is_finite(dt) and dt > 0.0 and dt <= 50.0 and ready() and host.s.mode == "playing"
func tick_props(dt_ms: float) -> bool:
	if not _valid_step(dt_ms): return false
	var props: Object = _props_ref.get_ref()
	for id: String in _dumpster_ids:
		var prop: Dictionary = props.record(id)
		if float(prop.get("diveCdT",0)) > 0:
			prop.diveCdT -= dt_ms
			if prop.diveCdT <= 0: props.set_dumpster_looted(id,false)
	return true
func tick_bench(dt_ms: float) -> bool:
	if not _valid_step(dt_ms): return false
	if not host.s.get("sittingOnBench",false): return true
	host.s.benchSitT = float(host.s.get("benchSitT",0))+dt_ms
	host.s.benchSitGainT = float(host.s.get("benchSitGainT",0))+dt_ms
	while host.s.benchSitGainT >= 2000:
		host.s.benchSitGainT -= 2000; host.p.brain = minf(100,host.p.brain+1)
	if host.s.benchSitT >= 60000:
		host.unlock_achievement("bench_press")
		host.s.benchSitPasserT = float(host.s.get("benchSitPasserT",0))+dt_ms
		if host.s.benchSitPasserT > 30000:
			host.s.benchSitPasserT = 0.0; _toast(PASSERS[host.random_index(PASSERS.size())],3200)
	return true

func _answer_phone() -> Dictionary:
	if not _pending_phone.is_empty(): return _fail("placement_pending")
	if float(host.s.get("phonePropRingT",0)) <= 0: return _fail("not_ringing")
	var spatial: Object = _object(_spatial_ref,&"stage_cash_pickup")
	if spatial == null: return _fail("missing_spatial_adapter")
	host.s.phonePropRingT = 0.0
	_pending_phone = {"line":host.random_index(_phones.size()),"player":host.p,"state":host.s}
	_phone_retry_ms = 250.0
	var committed := _commit_phone()
	return {"ok":true,"closed":true,"pending":not committed,"committed":committed}
func _commit_phone() -> bool:
	if _pending_phone.is_empty() or not ready(): return false
	if not is_same(_pending_phone.player,host.p) or not is_same(_pending_phone.state,host.s): _pending_phone.clear(); return false
	var index: int = _pending_phone.line
	var point := Vector2(1800,1320)
	if _phones[index].get("planted",false):
		var spatial: Object = _object(_spatial_ref,&"stage_cash_pickup")
		if spatial == null: return false
		var proposed: Variant = spatial.call(&"stage_cash_pickup",point,100.0)
		var bounds: Dictionary = host.content.world.bounds
		if not proposed is Vector2 or not proposed.is_finite() or proposed.distance_to(point) > 100.0001 or proposed.x < 0 or proposed.y < 0 or proposed.x > bounds.w or proposed.y > bounds.h: return false
		point = proposed
	_pending_phone.clear()
	host.s.publicPhoneAnswered = int(host.s.get("publicPhoneAnswered",0))+1
	_sound("dialogue"); _toast("📞 PUBLIC PHONE\n\n"+str(_phones[index].text),6000)
	if index == 5: host.p.brain = maxf(0,host.p.brain-4)
	elif index == 8: host.p.hp = minf(host.p.maxHp,host.p.hp+4)
	elif _phones[index].get("planted",false):
		_serial += 1
		var id := "cp_phone_church_%d_%d" % [get_instance_id(),_serial]
		host.cash_piles.append({"id":id,"x":point.x,"y":point.y,"amt":50,"collected":false,"intro":false})
		host.s.flags.churchLoadedDumpsterX = 1800; host.s.flags.churchLoadedDumpsterY = 1320
		host.emit_event("cash_spawned",{"id":id})
		_feed("got a tip on a dumpster behind the church. anonymous. probably a setup.")
	if host.s.publicPhoneAnswered >= 5: host.unlock_achievement("phone_booth_prophet")
	_save(); _gesture("phone")
	return true
func tick_phone(dt_ms: float) -> bool:
	if not _valid_step(dt_ms): return false
	if not _pending_phone.is_empty():
		_phone_retry_ms -= dt_ms
		if _phone_retry_ms <= 0: _phone_retry_ms = 250.0; _commit_phone()
		return true
	if host.s.get("publicPhoneT") == null: host.s.publicPhoneT = 240000.0+host.random_float()*240000.0
	if float(host.s.get("phonePropRingT",0)) > 0:
		host.s.phonePropRingT = maxf(0,host.s.phonePropRingT-dt_ms)
	else:
		host.s.publicPhoneT -= dt_ms
		if host.s.publicPhoneT <= 0 and host.s.flags.get("introDone",false):
			host.s.publicPhoneT = 240000.0+host.random_float()*240000.0; host.s.phonePropRingT = 30000.0
			_sound("dialogue"); _feed("a phone is ringing in the scrap yard.","@local_eyewitness")
	return true
func snapshot() -> Dictionary:
	if not _same_epoch(): return {}
	return {"sitting":host.s.get("sittingOnBench",false),"sit_ms":host.s.get("benchSitT",0),"ring_ms":host.s.get("phonePropRingT",0),"phone_pending":not _pending_phone.is_empty()}
