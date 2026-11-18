class_name RockBottomCooking
extends RefCounted
## One authoritative heat record; world clocks are paused by Runtime in cookmini.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const MODES := ["slow","fast","shakes","all","propane"]
const PACKETS_PER_TICK: int = 2048
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var inventory: RefCounted
var _configs: Dictionary = {}
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _heat: Dictionary = {}
var _menu_active: bool = false
var _menu_amount: int = 0
var _offered: Array[Dictionary] = []

func _init(owner: RefCounted,spatial: Object) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null
	session = Session.new(owner,self,&"_session_available"); inventory = Inventory.new(owner)
	_configs = owner.definition("src/minigames/heat.js","COOK_MODES",{}).duplicate(true)
func ready() -> bool:
	if host == null or _configs.size() != 5: return false
	for mode: String in MODES:
		if not _configs.get(mode) is Dictionary: return false
	return true
func _same_epoch() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func is_active() -> bool: return _same_epoch() and not _heat.is_empty() and is_same(host.s.get("heat"),_heat) and _heat.get("active",false)
func is_resolving() -> bool: return is_active() and _heat.phase == "resolve"
func _session_available(id: String) -> bool: return id == "block" and _same_epoch() and _menu_active and host.s.mode == "dialogue"
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _feed(text: String,author: String) -> void: host.emit_event("feed",{"text":text,"author":author})
func _torch() -> bool: return host.p.equip.get("tool") == "propane_torch"
func _at_block() -> bool:
	var center: Vector2 = host.player_center()
	for zone: Dictionary in host.content.world.zones:
		if zone.id == "block": return center.x >= zone.x and center.x <= zone.x+zone.w and center.y >= zone.y and center.y <= zone.y+zone.h
	return false
static func predictor(brain: float,rocked: bool,dirty: int) -> String:
	if rocked and dirty > 0: return "rocked + dirty → good luck."
	if rocked: return "rocked → hands aren't yours. the bar shrinks."
	if brain >= 70 and dirty == 0: return "sober + clean → wider sweet spot."
	if brain >= 70 and dirty > 0: return "sober. but pinky in the bag. the cut argues with the math."
	if brain <= 30 and dirty > 0: return "zonked + dirty → the smoke writes its own ending."
	if brain <= 30: return "zonked → narrow window. read the needle."
	if dirty > 0: return "dirty packets first. soap is louder."
	return "the heat is the heat. the needle is the needle."
func _option(id: String,label: String,enabled: bool) -> Dictionary: return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else "unavailable"}
func open_menu() -> Dictionary:
	if not ready(): return _fail("missing_content")
	if is_active() or (_menu_active and _same_epoch()): return _fail("activity_active")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	var spatial: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if not _at_block() or spatial == null or not spatial.has_method(&"can_use_zone") or spatial.call(&"can_use_zone","block") != true: return _fail("out_of_reach")
	cancel("replace_menu")
	_player_epoch = host.p; _state_epoch = host.s; _menu_active = true; _menu_amount = int(host.p.supplies)
	var have: int = _menu_amount
	var dirty: int = mini(int(host.p.dirtySupplies),have)
	_offered = [
		_option("slow","low and slow. (1 packet, safe.)" if have >= 1 else "you have no packets.",have >= 1),
		_option("fast","fast cook. (3 packets, risky.)" if have >= 3 else "fast cook (need 3 packets.)",have >= 3),
		_option("shakes","shaky hands special. (1 packet, all-or-nothing.)" if have >= 1 and host.p.shakes >= 60 else ("shakes too steady for the special." if host.p.shakes < 60 else "need a packet."),have >= 1 and host.p.shakes >= 60),
		_option("all","cook all (%d packets)." % have if have >= 5 else "cook all (need 5+ packets.)",have >= 5)]
	if _torch(): _offered.append(_option("propane","propane. (1 packet. tight bar. big yield.)" if have >= 1 else "propane. (need a packet.)",have >= 1))
	_offered.append(_option("leave","leave.",true))
	var dirty_line: String = "\n%d of them are pinky's house cut. (dirty first.)" % dirty if dirty > 0 else ""
	var text: String = "you have %d packet%s.%s\nthe crate is a kitchen now.\nbrain: %d · shakes: %d.\n%s%s" % [have,"" if have == 1 else "s",dirty_line,int(floor(host.p.brain+0.5)),int(floor(host.p.shakes+0.5)),predictor(host.p.brain,host.p.rockedT > 0,dirty),"\npropane. you bought it. or you found it. it doesn't care." if _torch() else ""]
	var actions: Array[String] = []
	for option: Dictionary in _offered: actions.append(option.id)
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin("block",actions)
	if not opened.ok: cancel("failed_menu"); return opened
	return {"ok":true,"domain":"cooking","token":opened.token,"actor":"block","title":"THE CRATE (KITCHEN)","text":text,"options":_offered.duplicate(true)}
func select(token: Variant,mode: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,mode)
	if not accepted.ok:
		if accepted.reason != "stale_session": cancel("invalid_session")
		return accepted
	if mode == "leave": cancel("leave"); return {"ok":true,"closed":true}
	var offered: bool = false
	for option: Dictionary in _offered:
		if option.id == mode: offered = option.enabled; break
	var n: int = _menu_amount if mode == "all" else (3 if mode == "fast" else 1)
	if not offered or mode not in MODES or n <= 0 or host.p.supplies < n or (mode == "shakes" and host.p.shakes < 60) or (mode == "propane" and not _torch()):
		cancel("unavailable"); return _fail("action_unavailable")
	_menu_active = false; _offered.clear()
	var cfg: Dictionary = _configs[mode]
	var width: float = cfg.baseWidth+clampf((host.p.brain-30.0)/70.0,-0.4,0.6)*0.10
	if host.p.rockedT > 0: width -= 0.06
	width = clampf(width,0.05,0.40)
	var center: float = clampf(cfg.sweetCenter+(host.random_float()*2.0-1.0)*cfg.sweetSpread,0.10,0.95)
	_heat = {"active":true,"mode":mode,"n":n,"fillMs":cfg.fillMs,"burnZone":cfg.burnZone,"sweetCenter":center,"sweetHalf":width/2.0,"progress":0.0,"t":0.0,"phase":"fill","lockedAt":null,"outcome":null,"holdT":0.0,"idleAfterFill":1000.0}
	host.s.heat = _heat; host.s.mode = "cookmini"; _sound("dialogue")
	host.emit_event("cooking_changed")
	return {"ok":true,"closed":true,"started":true,"mode":"cookmini"}
func tick(dt_ms: float) -> bool:
	if not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	if not is_active():
		if not _same_epoch(): cancel("replaced_state")
		return false
	if host.s.mode != "cookmini" or host.s.get("hitPause",0) > 0: return false
	match _heat.phase:
		"fill":
			_heat.t += dt_ms; _heat.progress = minf(1.0,_heat.t/_heat.fillMs)
			if _heat.progress >= 1: _heat.phase = "idle"
		"idle":
			_heat.idleAfterFill -= dt_ms
			if _heat.idleAfterFill <= 0: _heat.lockedAt = 1.0; lock()
		"hold":
			_heat.holdT -= dt_ms
			if _heat.holdT <= 0: _prepare_resolution()
		"resolve": _resolve_chunk()
	return true
func tick_presentation(dt_ms: float) -> bool:
	if host == null or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	if float(host.s.get("smokeT",0)) > 0: host.s.smokeT = maxf(0,float(host.s.smokeT)-dt_ms)
	return true
func lock() -> Dictionary:
	if not is_active() or host.s.mode != "cookmini" or _heat.phase not in ["fill","idle"]: return _fail("not_lockable")
	if _heat.lockedAt == null: _heat.lockedAt = clampf(_heat.progress,0,1)
	_heat.phase = "hold"; _heat.holdT = 600.0; _heat.outcome = _outcome(_heat)
	_sound("coin" if _heat.outcome == "perfect" else ("pickup" if _heat.outcome == "ok" else ("hurt" if _heat.outcome == "burn" else "glassBreak")))
	host.emit_event("cooking_changed")
	return {"ok":true,"outcome":_heat.outcome}
func _outcome(h: Dictionary) -> String:
	var x: float = h.lockedAt
	var distance: float = absf(x-h.sweetCenter)
	var half: float = h.sweetHalf
	if x < 0.25 and distance > half: return "undercook"
	if x >= 1.0-h.burnZone: return "burn"
	if distance <= half: return "perfect"
	if distance <= half*1.8: return "ok"
	if distance <= half*3.0: return "bad"
	if x < 0.20: return "undercook"
	return "soaprock" if host.random_float() < 0.15 else "bad"
func _cost(n: int,dirty: int) -> void:
	host.p.supplies = maxi(0,int(host.p.supplies)-n); host.p.dirtySupplies = maxi(0,int(host.p.dirtySupplies)-dirty)
func bail() -> Dictionary:
	if is_resolving(): return _fail("resolution_pending")
	if not is_active():
		if _menu_active and _same_epoch(): cancel("menu_escape"); return {"ok":true,"closed":true}
		return _fail("inactive")
	var n: int = int(_heat.n)
	var dirty: int = mini(n,int(host.p.dirtySupplies))
	_cost(n,dirty); _clear_heat()
	_toast("you walked away.\nthe supplies don't walk back.",2800)
	_feed("walked away from a half-cooked batch. the crate is patient.","@blocklog")
	host.emit_event("save_requested"); return {"ok":true,"closed":true}
func cancel(_reason: String) -> bool:
	if is_resolving(): return false
	if _same_epoch():
		if not _heat.is_empty() and is_same(host.s.get("heat"),_heat): host.s.heat = null
		if (_menu_active and host.s.mode == "dialogue") or (not _heat.is_empty() and host.s.mode == "cookmini"): host.s.mode = "playing"
	session.close(); _menu_active = false; _offered.clear(); _heat = {}; _player_epoch = {}; _state_epoch = {}
	return true
func _clear_heat() -> void:
	host.s.heat = null; host.s.mode = "playing"
	session.close(); _menu_active = false; _offered.clear(); _heat = {}; _player_epoch = {}; _state_epoch = {}
	host.emit_event("cooking_changed")
func snapshot() -> Dictionary:
	if not is_active(): return {}
	var result: Dictionary = _heat.duplicate(true); result.erase("_calc")
	return result
func _prepare_resolution() -> void:
	var bb: float = clampf((host.p.brain-30.0)/70.0,-0.4,0.6)
	if host.p.rockedT > 0: bb -= 0.25
	_heat._calc = {"n":int(_heat.n),"mode":str(_heat.mode),"outcome":str(_heat.outcome),"bb":bb,"dirty":mini(int(_heat.n),int(host.p.dirtySupplies)),"processed":0,"rocks":0,"burnt":0}
	_heat.phase = "resolve"
	_resolve_chunk()
func _resolve_chunk() -> void:
	var calc: Dictionary = _heat._calc
	if calc.outcome not in ["burn","undercook"]:
		var dbl: float
		var brn: float
		match calc.mode:
			"slow": dbl = 0.08+calc.bb*0.15; brn = 0.10-calc.bb*0.08
			"fast": dbl = 0.35+calc.bb*0.20; brn = 0.30-calc.bb*0.10
			"shakes": dbl = 0.55; brn = 0.45
			"propane": dbl = 0.30+calc.bb*0.20; brn = 0.20-calc.bb*0.10
			_: dbl = 0.15+calc.bb*0.18; brn = 0.18-calc.bb*0.10
		dbl = clampf(dbl,0,0.7); brn = clampf(brn,0.02,0.5)
		var stop: int = mini(calc.n,calc.processed+PACKETS_PER_TICK)
		while calc.processed < stop:
			var roll: float = host.random_float()
			if roll < brn: calc.burnt += 1
			elif roll < brn+dbl: calc.rocks += 2
			else: calc.rocks += 1
			calc.processed += 1
		if calc.processed < calc.n: return
	_clear_heat() # Revoke acceptance before the sole resource commit.
	_commit(calc)
func _commit(calc: Dictionary) -> void:
	var n: int = calc.n
	var dirty: int = calc.dirty
	var mode: String = calc.mode
	var outcome: String = calc.outcome
	if outcome == "burn":
		_cost(n,dirty); host.p.brain = maxf(0,host.p.brain-10); host.p.wanted = minf(3,host.p.wanted+1); host.s.smokeT = 2000.0
		_sound("hurt"); _sound("glassBreak")
		_toast("the smoke is in the floor.\nit is in your hair.\nit will be in your hair on tuesday.",4200)
		if host.random_float() < 0.5: _feed("someone burnt the block. it's bad out here.","@crackheadcent")
		host.unlock_achievement("controlled_burn")
		if n >= 3: host.unlock_achievement("arson_of_nothing")
		host.emit_event("save_requested"); return
	if outcome == "undercook":
		_cost(n,dirty); _sound("hurt")
		_toast("it never set.\nyou waited.\nnothing crystallized.\nyou sit. you don't move.",4200)
		if host.random_float() < 0.5: _feed("nothing happened today. it counts.","@blocklog")
		host.emit_event("save_requested"); return
	var rocks: int = calc.rocks
	var burnt: int = calc.burnt
	if outcome == "soaprock":
		rocks = int(floor(rocks*0.5)); _cost(n,dirty); host.p.soapRocks += rocks
		host.p.brain = maxf(0,host.p.brain-mini(6,1+n)); host.p.shakes = minf(100,host.p.shakes+2*n)
		_sound("hurt")
		_toast("· batch ·\n- %d packet%s\n+ %d 'rock%s'\nit looks right. it isn't." % [n,"" if n == 1 else "s",rocks,"" if rocks == 1 else "s"],4200)
		if host.random_float() < 0.5: _feed("cut is talking.","@hardcandy")
		host.emit_event("save_requested"); return
	if mode == "propane": rocks = int(floor(rocks*1.30))
	rocks = maxi(0,int(floor(rocks*(1.15 if outcome == "perfect" else (0.60 if outcome == "bad" else 1.0)))))
	var soap: int = 0
	var soap_rate: float = clampf((dirty*0.25+(n-dirty)*0.12)/float(n)*(0.70 if outcome == "perfect" else (1.50 if outcome == "bad" else 1.0)),0,1)
	if mode != "shakes" and rocks > 0 and host.random_float() < soap_rate: soap = 1; rocks -= 1
	_cost(n,dirty); host.p.rocks += rocks
	if soap > 0: inventory.append_item("soap","a small bar of soap (oops)")
	host.p.brain = maxf(0,host.p.brain-mini(6,1+n)); host.p.shakes = minf(100,host.p.shakes+(0 if mode == "shakes" else 2*n))
	host.p.lifetime.rocksCooked = int(host.p.lifetime.get("rocksCooked",0))+rocks
	if rocks > 0: _sound("coin")
	if burnt > 0: _sound("hurt")
	_sound("glassBreak")
	if rocks > 0 and host.s.quests.has("finisher") and not host.s.quests.finisher.done:
		host.s.quests.finisher.done = true; _toast("· QUEST COMPLETE ·\nTHE FINISHER"); _sound("rankUp")
	if host.p.lifetime.rocksCooked >= 10: host.unlock_achievement("chef")
	if burnt == n and n >= 3: host.unlock_achievement("arson_of_nothing")
	if outcome == "perfect": host.unlock_achievement("the_heat_held")
	var lines: Array[String] = ["- %d packet%s" % [n,"" if n == 1 else "s"]]
	if rocks > 0: lines.append("+ %d rock%s" % [rocks,"" if rocks == 1 else "s"])
	if soap > 0: lines.append("+ 1 'rock' (it's soap. it happens.)")
	if burnt > 0: lines.append("burnt %d.\nthe crate has a smell now." % burnt)
	var header: String = "the heat held." if outcome == "perfect" else ("close enough. the rock is the rock." if outcome == "ok" else "the smell is wrong. you did this wrong.")
	_toast("· batch ·\n"+header+"\n"+"\n".join(lines),4200)
	if host.random_float() < 0.5:
		if outcome == "perfect": _feed("the chef. quiet today. respect.","@hardcandy")
		elif outcome == "ok": _feed("cooked %d on the crate. the crate is a kitchen." % rocks,"@crackheadcent")
		else: _feed("the smell is wrong on the block.","@blocklog")
	if n >= 3 and outcome in ["perfect","ok"] and host.random_float() < 0.35:
		host.p.wanted = minf(3,host.p.wanted+1)
		host.emit_event("delayed_toast",{"delay_ms":2200,"text":"a neighbor opens a window.\nthe neighbor closes the window.\nwanted +1.","duration_ms":2800})
	host.emit_event("save_requested")
