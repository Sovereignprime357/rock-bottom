class_name RockBottomOldSchool
extends RefCounted
## Source Old School modal. Bosses owns encounter/HP/death; GameState owns rewards.
const Session = preload("res://scripts/action_session.gd")
const LOCKED := "the door is chained.\nthe chain is rusted.\nyou don't have what it takes to break it yet.\n(rank 3 required.)"
const LOUD := "inside. dust. broken desks.\nyou hear something in the gym.\nit is breathing.\nit is large."
const QUIET := "inside. dust. broken desks.\nthe gym is quiet.\nthe walls smell of pennies."
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _boss_ref: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _door: Dictionary = {}
var _active: bool = false
var _locked: bool = false
var _captured_alive: bool = false
var session: RefCounted
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null

func _init(owner: RefCounted,spatial: Object,bosses: Object) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null; _boss_ref = weakref(bosses) if bosses != null else null
	_door = owner.definition("src/dialogue/vendors_places.js","OLD_SCHOOL_DOOR",{}).duplicate(true)
	session = Session.new(owner,self,&"_session_available")
	_player_epoch = owner.p; _state_epoch = owner.s
func _boss() -> Object: return _boss_ref.get_ref() if _boss_ref != null else null
func _bound() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func ready() -> bool:
	var boss: Object = _boss()
	return host != null and not _door.is_empty() and boss != null and boss.has_method(&"prepare_old_school_brutus") and boss.has_method(&"commit_old_school_brutus") and boss.has_method(&"discard_old_school_brutus")
func supports(id: String) -> bool: return id == "oldschool"
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _done() -> Dictionary: return {"ok":true,"closed":true}
func _toast(text: String,ms: int) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound() -> void: host.emit_event("sound",{"id":"glassBreak"})
func _save() -> void: host.emit_event("save_requested")
func _actor(alive_only: bool = false) -> Dictionary:
	for actor: Dictionary in host.npcs:
		if actor.get("id") == "os_brutus" and (not alive_only or not actor.get("dead",false)): return actor
	return {}
func _session_available(id: String) -> bool: return _bound() and _active and id == "oldschool" and host.s.mode == "dialogue"
func close() -> void:
	session.close()
	if _active and _bound() and host.s.mode == "dialogue": host.s.mode = "playing"
	_active = false; _locked = false; _captured_alive = false
func _page(locked: bool) -> Dictionary:
	_locked = locked; _captured_alive = not _actor(true).is_empty(); _active = true
	var options: Array = []
	var actions: Array[String] = []
	if not locked:
		options.append({"id":"rip","label":"rip copper from the walls. (40% spawn risk.)","enabled":true}); actions.append("rip")
	options.append({"id":"leave","label":"leave.","enabled":true}); actions.append("leave")
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin("oldschool",actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"oldschool","actor":"oldschool","token":opened.token,"title":"THE OLD SCHOOL","text":LOCKED if locked else LOUD if _captured_alive else QUIET,"options":options}
func open(id: String = "oldschool") -> Dictionary:
	if not supports(id): return _fail("unknown_target")
	if not ready(): return _fail("missing_dependency")
	if not _bound():
		close(); _player_epoch = host.p; _state_epoch = host.s
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	var dx: float = float(host.p.x)+float(host.p.w)*0.5-float(_door.x)-float(_door.w)*0.5
	var dy: float = float(host.p.y)+float(host.p.h)*0.5-float(_door.y)-float(_door.h)*0.5
	if dx*dx+dy*dy >= 44.0*44.0: return _fail("out_of_reach")
	var spatial: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if spatial == null or not spatial.has_method(&"can_reach_target"): return _fail("missing_spatial_adapter")
	var reach: Variant = spatial.call(&"can_reach_target","oldschool")
	if not _bound(): return _fail("replaced_state")
	if not reach is bool or not reach: return _fail("out_of_reach")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	close(); return _page(int(host.p.rank) < 3)
func _discard(plan: Dictionary) -> void:
	if not plan.is_empty() and _boss() != null: _boss().call(&"discard_old_school_brutus",plan)
func _spawn(plan: Dictionary) -> bool:
	# Source duplicate guard includes dead records. Such a no-op needs no physics.
	if not _actor().is_empty(): _discard(plan); return _bound()
	if plan.is_empty() or _boss() == null: return false
	var accepted: Variant = _boss().call(&"commit_old_school_brutus",plan)
	return _bound() and accepted is bool and accepted
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	var captured_alive: bool = _captured_alive; var locked: bool = _locked
	close()
	if action == "leave": return _done()
	if action != "rip" or locked: return _fail("action_unavailable")
	if not _bound() or not ready(): return _fail("replaced_state")
	var first: bool = not host.s.flags.get("osBrutusKilled",false) and not captured_alive
	var plan: Dictionary = {}
	if not captured_alive and _actor().is_empty():
		var prepared: Variant = _boss().call(&"prepare_old_school_brutus")
		if not _bound():
			if prepared is Dictionary: _discard(prepared)
			return _fail("replaced_state")
		if not prepared is Dictionary or not prepared.get("ok",false): return _fail("boss_unavailable")
		plan = prepared
		if host.s.mode != "playing": _discard(plan); return _fail("wrong_mode")
	if first:
		_sound()
		if not _spawn(plan): return _fail("boss_commit_failed")
		_toast("the copper is here. so is OLD SCHOOL BRUTUS.\nhe was sleeping in the gym. he is no longer sleeping.\nno copper this time.",4400)
		host.s.mode = "playing"; _save()
	else:
		host.p.copper += 2; host.s.counters.copperStripped = int(host.s.counters.get("copperStripped",0))+2
		if host.s.counters.copperStripped >= 10: host.unlock_achievement("copper_singer")
		_sound(); _toast("+ 2 pure copper\nthe pipe groans.\nsomething hears it.",3000)
		if not captured_alive and host.random_float() < 0.4:
			if not _bound(): _discard(plan); return _fail("replaced_state")
			if not _spawn(plan): return _fail("boss_commit_failed")
			host.s.mode = "playing"
		else:
			_discard(plan)
			if not _bound(): return _fail("replaced_state")
			_save(); var next: Dictionary = _page(false)
			host.emit_event("gesture",{"kind":"interact","accepted":true,"target":"oldschool"}); return next
	host.emit_event("gesture",{"kind":"interact","accepted":true,"target":"oldschool"})
	return _done()
