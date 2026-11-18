class_name RockBottomNeighborhoodUtilities
extends RefCounted
## Source utility state lives only in GameState. Scene owns input and presentation.
const Session = preload("res://scripts/action_session.gd")
const CLOCKS := ["tweakerT","tweakerCdT","autoSaveT"]
const THOUGHTS := [
	"you sit. the crate accepts you. you remember nothing useful.",
	"you sit. a cloud passes. it does not acknowledge you.\n(+1 cred for the patience.)",
	"you sit. a possum walks by. nods. continues.\nyou are on his route.",
	"you sit. you remember a birthday from 1996.\nit was not yours.",
	"you sit. the milk crate is very old.\nit has seen kings.",
	"you sit. you almost have a thought.\nit leaves."]
# Underpass is independent; the remaining rows form the original else-if chain.
const ENTRIES := [
	["underpass","underpassEntered","under the bridge. the bridge has ears.","@crackheadcent","the air changes.\nyou can hear yourself walk.",3600],
	["trainyard","trainYardEntered","trains stopped running here. they still come through.","@blocklog","the rails hum.\nthe rails are warm.\nthe rails are not used.",4000],
	["park","parkEntered","the pigeons remember faces. the philosopher remembers names.","@hardcandy","you are in the park.\nthe fountain is still running.",3600],
	["skidrow","skidRowEntered","skid row knows you didn't ask first.","@crackheadcent","the alleys are tight.\nthe air is heavier here.",3600],
	["oldschool","oldSchoolEntered","the old school still has copper in the walls. the school still has brutus in the gym.","@blocklog","the old school stands.\nthe paint is gone.\nthe building is not.",3600],
	["warehouse_row","warehouseRowEntered","warehouse row received nothing. returns accepted nothing.","@blocklog","two warehouses.\nthree unit numbers.\none manifest refuses all of them.",3800],
	["canal","canalEntered","the water department marked the canal water pending.","@crackheadcent","the canal is dry.\nthe water gauge says nine.\ngutter greg counted the duck.",4000],
	["the_lot","theLotEntered","walk-ins accepted at the office. tax help unavailable.","@hardcandy","the lot has forty spaces.\nzero cars.\none leasing guy.",3800],
	["blue_tarp_court","blueTarpCourtEntered","four tarps filed one court date. weather is named as counsel.","@blocklog","four tarps share one court date.\nnone brought identification.",3800],
	["cart_cavalry_keep","cartKeepEntered","the cart cavalry formed a line. one wheel attended.","@hardcandy","six carts form a cavalry line.\none has a wheel.",3800],
	["copper_choir_yard","copperChoirEntered","the copper choir is holding b flat until inventory closes.","@blocklog","the copper choir rehearses b flat.\nattendance is mandatory on paper.",4000],
	["throne_ditch","throneDitchEntered","the ditch has a chair. the chair has jurisdiction.","@crackheadcent","the ditch has a chair in it.\nthe chair has jurisdiction.",4000]]
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _zone: String = ""
var _day: bool = true
var _menu_active: bool = false
var _offered: Array[Dictionary] = []

func _init(owner: RefCounted,spatial: Object) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null
	session = Session.new(owner,self,&"_session_available")
	reset_session("cold")
func _bound() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func ready() -> bool: return _bound() and host.content.get("world",{}).get("zones") is Array
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _feed(text: String,author: String) -> void: host.emit_event("feed",{"text":text,"author":author})
static func _number(value: Variant,fallback: float = 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
static func _valid_step(dt_ms: float) -> bool: return is_finite(dt_ms) and dt_ms > 0.0 and dt_ms <= 50.0
func reset_session(kind: String) -> bool:
	if host == null or kind not in ["cold","fresh","restore"]: return false
	var previous: Dictionary = _state_epoch
	close()
	if kind != "cold" and not previous.is_empty():
		for key: String in CLOCKS:
			if previous.has(key): host.s[key] = _number(previous[key])
			else: host.s.erase(key)
	_player_epoch = host.p; _state_epoch = host.s
	release_squint()
	return true
func _session_available(id: String) -> bool:
	return _bound() and _menu_active and _zone == id and host.s.mode == "dialogue"
func close() -> void:
	session.close(); _menu_active = false; _zone = ""; _offered.clear()
	if _bound():
		release_squint()
		if host.s.mode == "dialogue": host.s.mode = "playing"
func _in_zone(id: String) -> bool:
	var point: Vector2 = host.player_center()
	for zone: Dictionary in host.content.world.zones:
		if zone.id == id: return point.x >= zone.x and point.x <= zone.x+zone.w and point.y >= zone.y and point.y <= zone.y+zone.h
	return false
func _option(id: String,label: String,enabled: bool = true) -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else "unavailable"}
func open_zone(id: String) -> Dictionary:
	if not ready(): return _fail("replaced_state")
	if id not in ["block","market"]: return _fail("unknown_zone")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	var spatial: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if not _in_zone(id) or spatial == null or not spatial.has_method(&"can_use_zone") or spatial.call(&"can_use_zone",id) != true: return _fail("out_of_reach")
	# The spatial adapter is external: a synchronous lifecycle callback may replace p/s.
	if not _bound(): return _fail("replaced_state")
	close(); _zone = id; _menu_active = true
	_day = not (float(host.s.dayTime) < 0.25 or float(host.s.dayTime) > 0.75)
	var title: String = "THE BLOCK" if id == "block" else "THE MARKETPLACE"
	var text: String = ""
	if id == "block":
		var rocks: int = int(host.p.rocks)+int(host.p.soapRocks)
		_offered.append(_option("smoke","smoke a rock. (-1 rock, +18s rocked-up)" if rocks > 0 else "smoke a rock. (you have none.)",rocks > 0 and host.p.rockedT <= 0))
		if host.s.flags.get("hasStripePackage",false): _offered.append(_option("package","open stripe's package. (alone, no one is watching.)"))
		_offered.append(_option("sleep","sleep until morning. (+50 hp · +25 brain · -1 wanted)"))
		_offered.append(_option("cooking","cook a batch. (🧪%d → rocks)" % host.p.supplies if host.p.supplies > 0 else "cook a batch. (you have no packets.)",host.p.supplies > 0))
		_offered.append(_option("think","sit on the crate and think."))
		for item: Dictionary in host.p.inventory:
			if item.get("id") == "lottery": _offered.append(_option("lottery","scratch the lottery ticket.")); break
		text = "the milk crate is here. the sky is here.\nyour shakes are %d. your brain is %d." % [int(floor(host.p.shakes+0.5)),int(floor(host.p.brain+0.5))]
	else:
		_offered.append(_option("change","ask for change. (chance of $1-5)"))
		_offered.append(_option("song","perform a song you don't know."))
		_offered.append(_option("trick","do a card trick you don't know."))
		text = "people are walking by.\nthey are pretending you are scenery." if _day else "the marketplace is asleep.\nyou could still try."
	_offered.append(_option("leave","leave."))
	var actions: Array[String] = []
	for option: Dictionary in _offered: actions.append(option.id)
	host.s.mode = "dialogue"; release_squint()
	var opened: Dictionary = session.begin(id,actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"utilities","token":opened.token,"actor":id,"title":title,"text":text,"options":_offered.duplicate(true)}
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	var enabled: bool = false
	for option: Dictionary in _offered:
		if option.id == action: enabled = option.enabled; break
	var captured_day: bool = _day
	close(); release_squint()
	if not enabled: return _fail("action_unavailable")
	if action == "leave": return {"ok":true,"closed":true}
	if action in ["smoke","sleep","cooking","package"]:
		return {"ok":true,"closed":true,"handoff":action,"zone":"block"}
	match action:
		"think":
			var thought: String = THOUGHTS[host.random_index(THOUGHTS.size())]
			if thought.contains("+1 cred"): host.p.cred += 1
			_toast(thought,4000)
		"lottery": _scratch()
		"change": _change(captured_day)
		"song":
			if host.random_float() < 0.4:
				host.p.cash += 3; _toast("+ $3\nyou hummed. people walked faster. one tipped.")
			else: _toast("you hummed. no one tipped.\nyou hum louder. still nothing.\nthe humming was the song.")
		"trick":
			if host.random_float() < 0.25:
				host.p.cash += 8; host.p.cred += 1; _toast("+ $8 + 1 cred\nit worked. you don't know how.\nneither does the audience.")
			else:
				host.p.wanted = minf(3.0,host.p.wanted+1.0)
				_toast("the trick was 'i have the card and now you don't.'\nthis is, in fact, theft.\nwanted +1")
	host.emit_event("gesture",{"action":"interact"})
	return {"ok":true,"closed":true}
func _scratch() -> void:
	var remaining: Array = []
	for item: Dictionary in host.p.inventory:
		if item.get("id") != "lottery": remaining.append(item)
	host.p.inventory = remaining
	var roll: float = host.random_float()
	if roll < 0.01:
		host.p.cash += 500
		_toast("· $500 ·\nyou won. the world is wrong.\nthe ticket combusts.",4500); _sound("coin")
		host.emit_event("news",{"text":"LOCAL MAN WINS $500. REFUSES INTERVIEW."})
		_feed("won the lottery. immediately spent half of it. on what.","@crackheadcent")
	elif roll < 0.15:
		var win: int = 5+host.random_index(15)
		host.p.cash += win; _toast("· $%d ·\na small win. dignity-shaped." % win,2500); _sound("coin")
	else: _toast("nothing. as ever.\nthe ticket smells like a basement.",2200)
	host.emit_event("save_requested")
func _change(day: bool) -> void:
	var roll: float = host.random_float()
	var modifier: float = 0.0 if day else -0.2
	if roll < 0.45+modifier:
		var got: int = 1+host.random_index(4)
		host.p.cash += got; _sound("coin")
		if got >= 4: host.s.counters.bigPan = int(host.s.counters.get("bigPan",0))+1
		_toast("+ $%d\na person handed it to you and immediately regretted it." % got)
	elif roll < 0.65+modifier:
		host.p.cash += 1; _toast("+ $1\nyou were given a single dollar with eye contact you did not consent to.")
	elif roll < 0.85:
		_toast("a woman gave you advice.\nthe advice was 'have you tried not.'\n(- 1 brain)")
		host.p.brain = maxf(0.0,host.p.brain-1.0)
	else:
		_toast("a man told you to 'get a job.'\nhe has not had one since 2003.\n+1 cred (out of spite)"); host.p.cred += 1
func press_squint() -> Dictionary:
	if not ready(): return _fail("replaced_state")
	if host.s.mode != "playing": return _fail("wrong_mode")
	if host.s.get("keys") is Array and not host.s.keys.has("f"): host.s.keys.append("f")
	if host.p.stunT > 0: return _fail("stunned")
	if _number(host.s.get("tweakerCdT")) > 0 or host.p.brain <= 0:
		if host.p.brain <= 0: _toast("your brain has nothing left to give.",1500)
		return _fail("cooldown" if host.p.brain > 0 else "empty_brain")
	if _number(host.s.get("tweakerT")) != 0: return _fail("vision_not_zero")
	host.s.tweakerT = 3000.0; host.s.tweakerCdT = 6000.0
	host.p.brain = maxf(0.0,host.p.brain-5.0)
	return {"ok":true}
func release_squint() -> void:
	if _bound() and host.s.get("keys") is Array: host.s.keys.erase("f")
func tick_squint(dt_ms: float,held: bool) -> bool:
	if not ready() or not _valid_step(dt_ms) or host.s.mode != "playing": return false
	if _number(host.s.get("tweakerCdT")) > 0: host.s.tweakerCdT -= dt_ms
	if held and _number(host.s.get("tweakerT")) > 0 and host.p.brain > 0:
		host.s.tweakerT -= dt_ms; host.p.brain = maxf(0.0,host.p.brain-dt_ms*0.002)
		if host.p.brain <= 0:
			host.s.tweakerT = 0.0; _toast("your brain has nothing left to give.",1800)
	elif not held: host.s.tweakerT = 0.0
	return true
func tick_zone_entries() -> Array[String]:
	var entered: Array[String] = []
	if not ready() or host.s.mode != "playing": return entered
	for index: int in range(ENTRIES.size()):
		var row: Array = ENTRIES[index]
		if host.s.flags.get(row[1],false) or not _in_zone(row[0]): continue
		host.s.flags[row[1]] = true
		_feed(row[2],row[3]); _toast(row[4],row[5]); host.emit_event("save_requested")
		entered.append(row[1])
		if index > 0: break
	return entered
func finish_world_step(dt_ms: float) -> bool:
	if not ready() or not _valid_step(dt_ms): return false
	host.s.autoSaveT = _number(host.s.get("autoSaveT"))+dt_ms
	if host.s.autoSaveT > 45000.0:
		host.s.autoSaveT = 0.0; host.emit_event("save_requested")
	return true
func cash_visible(pile: Dictionary) -> bool:
	if not ready() or pile.get("collected",false): return false
	if _number(host.s.get("tweakerT")) > 0 or pile.get("intro",false) or pile.get("tool") or pile.get("equip"): return true
	if not (pile.get("x") is int or pile.get("x") is float) or not (pile.get("y") is int or pile.get("y") is float): return false
	var point := Vector2(pile.x,pile.y)
	return point.is_finite() and host.player_center().distance_squared_to(point) < 3600.0
