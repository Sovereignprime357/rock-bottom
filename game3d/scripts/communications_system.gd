class_name RockBottomCommunications
extends RefCounted
## One session-global phone/ticker owner; player effects remain on GameState.
const Inventory = preload("res://scripts/inventory.gd")
const MODULE := "src/systems/communications.js"
const EVENT_IDS := ["forklift_possum","cloud_yell","doordash","car_alarm","chimichanga","horse_nod","pothole_say","pigeon_road","forget_year","puddle_wave","pigeon_change","sushi_wedding","sandwich_lecture","siren_distant","tony_blinks","dachshund","guy_running","helicopter","twin_possums","wedding_guy","pizza_box","school_bus","mom_drives_by","free_meatball","man_with_sign","singing_streetlight","free_money","philosopher_man","pigeon_gang"]
const ROTATE_MS: float = 50000.0
var _host_ref: WeakRef
var _props_ref: WeakRef
var _unix_ms: Callable
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var _posts: Array[Dictionary] = []
var _visible: bool = false
var _news_text: String = ""
var _news_index: int = 0
var _wall_ms: float = 0.0
var _wall_started: bool = false
var _rotation_elapsed: float = 0.0

func _init(owner: RefCounted,props: Object,unix_ms: Callable) -> void:
	_host_ref = weakref(owner)
	_props_ref = weakref(props) if props != null else null
	_unix_ms = unix_ms
	inventory = Inventory.new(owner)
	if ready(): _rotate(1)
func _data(key: String,fallback: Variant = null) -> Variant:
	return host.definition(MODULE,key,fallback) if host != null else fallback
func _now() -> float:
	if not _unix_ms.is_valid(): return NAN
	var value: Variant = _unix_ms.call()
	return float(value) if (value is int or value is float) and is_finite(float(value)) and value >= 0 else NAN
func _prop_owner() -> Object:
	var value: Object = _props_ref.get_ref() if _props_ref != null else null
	return value if value != null and value.has_method(&"ready") and value.has_method(&"garbage_reset") else null
func ready() -> bool:
	if host == null or not is_finite(_now()): return false
	var calls: Variant = _data("PHONE_CALL_LINES",[])
	var events: Variant = _data("WORLD_EVENTS",[])
	if not calls is Array or calls.size() != 12 or not events is Array or events.size() != EVENT_IDS.size(): return false
	for index: int in range(events.size()):
		if not events[index] is Dictionary or events[index].get("id") != EVENT_IDS[index]: return false
	for key: String in ["MOM_PROUD_LINES","NEWS_POOL","FEED_HANDLES"]:
		var rows: Variant = _data(key,[])
		if not rows is Array or rows.is_empty(): return false
	return _data("MOM_TIP_CALL") is Dictionary
func day_capabilities_ready() -> bool:
	var props: Object = _prop_owner()
	return ready() and props != null and props.ready() == true
func silence_active() -> bool:
	if host == null: return false
	var now: float = _now()
	var until: Variant = host.s.flags.get("silenceUntilT",0)
	return is_finite(now) and (until is int or until is float) and is_finite(float(until)) and float(until) > now
func _changed() -> void: host.emit_event("communications_changed")
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void:
	# Source traffic evaluates its pitch RNG before tone's audio-ready guard.
	# Keep its effect on subsequent gameplay choices; cached playback draws nothing.
	if id == "traffic": host.random_float()
	host.emit_event("sound",{"id":id})
func show_feed() -> bool:
	if not ready(): return false
	if not _visible: _visible = true; _changed()
	return true
func toggle_feed() -> bool:
	if not ready(): return false
	_visible = not _visible; _changed(); return true
func post(text: String,author: String = "") -> bool:
	if not ready(): return false
	if silence_active(): return true
	var handle: String = author
	if handle.is_empty():
		var handles: Array = _data("FEED_HANDLES",[])
		handle = str(handles[host.random_index(handles.size())])
	_posts.push_front({"h":handle,"t":text,"day":host.s.day})
	while _posts.size() > 8: _posts.pop_back()
	_changed()
	return true
func broadcast(text: String) -> bool:
	if not ready(): return false
	if silence_active(): return true
	_news_text = "· BREAKING · "+text+"   ◆   "+_news_text
	_changed(); return true
func consume_event(event: Dictionary) -> bool:
	var payload: Variant = event.get("payload",{})
	if not payload is Dictionary: return false
	if event.get("kind") == "feed":
		if not payload.get("text") is String or not payload.get("author","") is String: return false
		return post(payload.text,payload.get("author",""))
	if event.get("kind") == "news":
		return broadcast(payload.text) if payload.get("text") is String else false
	return false
func flush_pending_events() -> bool:
	if not ready(): return false
	var pending: Array[Dictionary] = []
	var kept: Array[Dictionary] = []
	for event: Dictionary in host.events:
		if event.get("kind") not in ["feed","news"]: kept.append(event); continue
		var payload: Variant = event.get("payload")
		if not payload is Dictionary or not payload.get("text") is String: return false
		if event.kind == "feed" and not payload.get("author","") is String: return false
		pending.append(event)
	host.events = kept
	for event: Dictionary in pending: consume_event(event)
	return true
func snapshot() -> Dictionary:
	return {"posts":_posts.duplicate(true),"visible":_visible,"displayed":_visible and host != null and host.s.mode == "playing","day":host.s.day if host != null else 0,"news_text":_news_text,"news_index":_news_index}
func _rotate(count: int) -> void:
	var pool: Array = _data("NEWS_POOL",[])
	if pool.is_empty() or count <= 0: return
	_news_index = (_news_index+(count-1)%pool.size())%pool.size()
	var lines: Array[String] = []
	for index: int in range(5): lines.append(str(pool[(_news_index+index)%pool.size()]))
	_news_text = "   ◆   ".join(lines)
	_news_index = (_news_index+1)%pool.size()
	_changed()
func advance_wall(monotonic_ms: float) -> bool:
	if not ready() or not is_finite(monotonic_ms) or monotonic_ms < 0 or (_wall_started and monotonic_ms < _wall_ms): return false
	if not _wall_started:
		_wall_started = true; _wall_ms = monotonic_ms; return true
	var elapsed: float = monotonic_ms-_wall_ms
	_wall_ms = monotonic_ms; _rotation_elapsed += elapsed
	if _rotation_elapsed >= ROTATE_MS:
		# Ticker-only catch-up is arithmetic; no unbounded callback loop.
		var rotations: float = floor(_rotation_elapsed/ROTATE_MS)
		_rotation_elapsed = fmod(_rotation_elapsed,ROTATE_MS)
		var pool: Array = _data("NEWS_POOL",[])
		_rotate(int(fmod(rotations,float(pool.size())))+pool.size())
	return true
func _ring(call: Dictionary) -> void:
	_sound("dialogue")
	_toast("📞 incoming call · "+str(call.from)+"\n\n"+str(call.text),5500)
	post("phone call from "+str(call.from).to_lower()+".","@phone_guy")
func ring_phone(index: int = -1) -> bool:
	if not ready() or host.s.mode != "playing" or index < -1 or index >= 12: return false
	var selected: int = host.random_index(12) if index == -1 else index
	var calls: Array = _data("PHONE_CALL_LINES",[])
	_ring(calls[selected])
	match selected:
		1: host.p.brain = maxf(0,host.p.brain-5)
		2: host.p.cash += 3
		6: host.p.brain = minf(100,host.p.brain+4)
		8: host.p.cred += 1
		11: host.p.brain = minf(100,host.p.brain+10)
	return true
func fire_mom_intro_once() -> bool:
	if not ready() or host.s.mode != "playing" or host.s.flags.get("momIntroFired",false): return false
	host.s.flags.momIntroFired = true
	_ring(_data("MOM_TIP_CALL",{})); host.emit_event("save_requested"); return true
func maybe_mom_proud() -> bool:
	if not ready() or host.s.mode != "playing" or host.s.flags.get("momProudCallDay",0) == host.s.day or host.p.faction.spiritual < 10 or silence_active(): return false
	host.s.flags.momProudCallDay = host.s.day
	var lines: Array = _data("MOM_PROUD_LINES",[])
	_ring({"from":"YOUR MOM","text":str(lines[host.random_index(lines.size())])+"\n(+5 brain)"})
	host.p.brain = minf(100,host.p.brain+5)
	return true
func dispatch_day_callback(kind: String) -> bool:
	if not day_capabilities_ready(): return false
	if kind == "mom_proud": maybe_mom_proud(); return true
	if kind != "garbage_truck": return false
	var props: Object = _prop_owner()
	_sound("traffic"); _sound("traffic")
	_toast("a garbage truck rumbles down the street.\nall dumpsters are reset.\none of them now has a 'TIPS' jar duct-taped to the side.",4200)
	post("garbage truck went through. fresh dumpsters in the neighborhood.","@local_eyewitness")
	var reset: Dictionary = props.garbage_reset()
	if reset.get("ok") != true: return false
	broadcast("GARBAGE TRUCK COMPLETES ROUTE. DUMPSTERS REOPEN FOR BUSINESS.")
	return true
func fire_random_event(index: int = -1) -> bool:
	if not ready() or index < -1 or index >= EVENT_IDS.size(): return false
	var selected: int = host.random_index(EVENT_IDS.size()) if index == -1 else index
	var entries: Array = _data("WORLD_EVENTS",[])
	var event: Dictionary = entries[selected]
	_toast(str(event.text),5500)
	match event.id:
		"cloud_yell": host.p.cred += 2
		"doordash": host.p.cash += 12
		"forget_year":
			host.p.brain = maxf(0,host.p.brain-3)
			inventory.append_item("cone","a traffic cone")
		"pigeon_change": host.p.cash += 4
		"sandwich_lecture": host.p.cred += 1
		"tony_blinks": host.p.cred += 5; broadcast("EYEWITNESS: TONY BLINKED. UNCONFIRMED.")
		"guy_running": host.p.cash += 3
		"wedding_guy": host.p.cash += 5
		"pizza_box": inventory.append_item("gold_tooth","a tooth (gold)")
		"mom_drives_by": host.p.brain = maxf(0,host.p.brain-3)
		"free_meatball": host.p.hp = minf(host.p.maxHp,host.p.hp+12)
		"free_money": host.p.cash += 20
		"philosopher_man":
			if host.p.cash >= 5: host.p.cash -= 5; host.p.cred += 6
	if event.get("sfx") is String: _sound(event.sfx)
	var headline: String = str(event.text).get_slice("\n",0)
	post(headline.to_lower(),"@local_eyewitness")
	if host.random_float() < 0.3: broadcast(headline)
	return true
