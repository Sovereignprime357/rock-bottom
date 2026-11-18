class_name RockBottomRhythm
extends RefCounted
## The source "rhythm" is an untimed sequence of numbered dialogue choices.
const Session = preload("res://scripts/action_session.gd")
const ARROWS := ["↑","↓","←","→"]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _memory_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var _sequence: Array[int] = []
var _index: int = 0
var _hits: int = 0
var _active: bool = false
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}

func _init(owner: RefCounted,spatial: Object,memory: Object) -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial) if spatial != null else null
	_memory_ref = weakref(memory) if memory != null else null
	session = Session.new(owner,self,&"_session_available")
func _dependency(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _same_epoch() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func _session_available(id: String) -> bool: return id == "karaoke" and _active and _same_epoch() and host.s.mode == "dialogue"
func is_active() -> bool: return _active and _same_epoch()
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func start_paid_karaoke() -> Dictionary:
	if host == null: return _fail("missing_owner")
	if is_active(): return _fail("activity_active")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	var singer: Dictionary = {}
	for actor: Dictionary in host.npcs:
		if actor.get("id") == "karaoke": singer = actor; break
	if singer.is_empty() or singer.get("dead",false): return _fail("missing_resident")
	var center := Vector2(float(singer.x)+float(singer.w)*0.5,float(singer.y)+float(singer.h)*0.5)
	if host.player_center().distance_squared_to(center) >= 3600.0: return _fail("out_of_reach")
	if host.p.cash < 5: return _fail("insufficient_cash")
	var memory: Object = _dependency(_memory_ref,&"record")
	if memory == null: return _fail("memory_unavailable")
	var spatial: Object = _dependency(_spatial_ref,&"can_reach_target")
	if spatial == null or spatial.can_reach_target("karaoke") != true: return _fail("out_of_reach")
	close()
	_player_epoch = host.p; _state_epoch = host.s
	_active = true; host.p.cash -= 5
	for index: int in range(8): _sequence.append(host.random_index(4))
	var menu := _menu()
	memory.record("laundromat","buy","karaoke")
	host.emit_event("activity_started",{"id":"karaoke"})
	return menu
func _menu() -> Dictionary:
	var options: Array[Dictionary] = []
	var actions: Array[String] = []
	for index: int in range(4):
		var id: String = "note:%d" % index
		actions.append(id)
		options.append({"id":id,"label":ARROWS[index]+" "+("(now!)" if index == _sequence[_index] else ""),"enabled":true,"reason":""})
	actions.append("forfeit")
	options.append({"id":"forfeit","label":"forfeit. (you sound tired)","enabled":true,"reason":""})
	var history: Array[String] = []
	for index: int in range(_index): history.append(ARROWS[_sequence[index]])
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin("karaoke",actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"activities","token":opened.token,"actor":"karaoke","title":"· %d / 8 ·" % (_index+1),"text":"next: "+ARROWS[_sequence[_index]]+"\n\nyour line:\n"+" ".join(history),"options":options}
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	if action == "forfeit":
		close(); _toast("you stop singing.\nthe crowd stays."); return {"ok":true,"closed":true}
	var chosen: int = int(action.get_slice(":",1))
	if chosen == _sequence[_index]: _hits += 1
	_index += 1
	if _index < 8: return _menu()
	var hits: int = _hits
	close() # Revoke completion before the single reward commit.
	var pay: int = hits*3
	var cred: int = int(floor(hits/2.0))
	host.p.cash += pay; host.p.cred += cred
	host.emit_event("sound",{"id":"coin"})
	_toast("· %d/8 hits ·\n+ $%d · + %d cred\nthe crowd was three people.\ntwo of them were waiting for the bus." % [hits,pay,cred],3000)
	if hits == 8:
		host.unlock_achievement("not_a_phase")
		host.emit_event("news",{"text":"KARAOKE PERFECTION REPORTED. WITNESSES UNAVAILABLE."})
	host.emit_event("save_requested"); host.emit_event("activity_completed",{"id":"karaoke","hits":hits})
	return {"ok":true,"closed":true}
func close() -> void:
	session.close(); _sequence.clear(); _index = 0; _hits = 0; _active = false
	_player_epoch = {}; _state_epoch = {}
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
