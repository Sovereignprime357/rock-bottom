class_name RockBottomCoreVendors
extends RefCounted
## Validated source Tony/Pete/Yuri commands. Scene adapters supply live visibility and combat.
const Inventory = preload("res://scripts/inventory.gd")
const Session = preload("res://scripts/action_session.gd")
const IDS := ["tony", "pete", "yuri"]
const TITLES := {"tony":"TRE BAG TONY", "pete":"PAWN SHOP PETE", "yuri":"YURI"}
const EMPTY_LINE := "pete is empty. pete is eating.\ncome back tomorrow."
var _host_ref: WeakRef
var _memory_ref: WeakRef
var _boss_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var session: RefCounted


func _init(owner: RefCounted, spatial_adapter: Object, memory: RefCounted = null, boss_adapter: Object = null) -> void:
	_host_ref = weakref(owner)
	_memory_ref = weakref(memory) if memory != null else null
	_boss_ref = weakref(boss_adapter) if boss_adapter != null else null
	inventory = Inventory.new(owner)
	session = Session.new(owner, spatial_adapter)


func _actor(id: String) -> Dictionary:
	if host != null:
		for actor: Dictionary in host.npcs:
			if actor.get("id") == id: return actor
	return {}


func _talk_reason(id: String) -> String:
	if host == null: return "missing_owner"
	if id not in IDS: return "unknown_vendor"
	if host.s.mode not in ["playing", "dialogue"]: return "wrong_mode"
	if host.s.get("bossKind", "") == "kingdom": return "active_boss"
	var actor: Dictionary = _actor(id)
	if actor.is_empty() or actor.get("dead", false): return "missing_vendor"
	if id == "pete" and actor.get("shopClosed", false): return "shop_closed"
	var center: Vector2 = Vector2(float(actor.x) + float(actor.w) * 0.5, float(actor.y) + float(actor.h) * 0.5)
	if host.player_center().distance_squared_to(center) >= 3600.0: return "out_of_reach"
	return ""


func _boss_available() -> bool:
	var adapter: Object = _boss_ref.get_ref() if _boss_ref != null else null
	if adapter == null or not adapter.has_method(&"can_start_tony") or not adapter.has_method(&"start_tony"): return false
	var answer: Variant = adapter.call(&"can_start_tony")
	return answer is bool and answer


func _start_boss() -> bool:
	if not _boss_available(): return false
	var adapter: Object = _boss_ref.get_ref()
	var answer: Variant = adapter.call(&"start_tony")
	return answer is bool and answer


func _option(id: String, label: String, enabled: bool = true, reason: String = "") -> Dictionary:
	return {"id":id, "label":label, "enabled":enabled, "reason":reason if not enabled else ""}


func _rock_price() -> int:
	return host.vendor_price(9 if int(host.p.faction.street) >= 10 else 10)


func _pete_room() -> int:
	return maxi(0, 200 - int(host.s.counters.get("peteCashToday", 0)))


func _flag(key: String) -> bool:
	var value: Variant = host.s.flags.get(key)
	return value is bool and value


func _loan_day() -> int:
	var value: Variant = host.s.flags.get("scrapLoanDay")
	return int(value) if (value is int or value is float) and is_finite(float(value)) else 0


func _options(id: String) -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	var cash: int = int(host.p.cash)
	var scrap: int = int(host.p.faction.scrap)
	match id:
		"tony":
			var price: int = _rock_price()
			opts.append(_option("buy_rock", "buy a rock. $%d." % price, cash >= price, "insufficient_cash"))
			var boss_ready: bool = int(host.p.tonyOffenses) < 2 or _boss_available()
			opts.append(_option("short", "short him. ($5)", cash >= 5 and boss_ready, "insufficient_cash" if cash < 5 else "boss_unavailable"))
			opts.append(_option("negotiate", "try to negotiate."))
			opts.append(_option("challenge", "challenge for the corner. (boss)" if host.p.cred >= 100 else "try to take the corner. (need 100 cred)", host.p.cred >= 100 and _boss_available(), "insufficient_cred" if host.p.cred < 100 else "boss_unavailable"))
		"yuri":
			var rate: int = 28 if scrap >= 10 else 25
			opts.append(_option("sell_copper", "sell 1 PURE COPPER. $%d." % rate, host.p.copper >= 1, "insufficient_copper"))
			opts.append(_option("sell_all_copper", "sell all pure copper.", host.p.copper >= 1, "insufficient_copper"))
			opts.append(_option("brutus", "ask about brutus."))
			opts.append(_option("dog", "ask about the dog."))
			if scrap >= 5 and not _flag("scrapHideoutOwned"):
				opts.append(_option("rent_shed", "rent the back-corner shed. $150." if cash >= 150 else "rent the shed. ($150 — short.)", cash >= 150, "insufficient_cash"))
		"pete":
			if scrap > -10:
				var empty: bool = _pete_room() == 0
				var rate: int = 17 if scrap >= 10 else 15
				opts.append(_option("sell_copper", "sell 1 PURE COPPER. (pete is empty.)" if empty else "sell 1 PURE COPPER. $%d." % rate, empty or host.p.copper >= 1, "insufficient_copper"))
				opts.append(_option("sock", "pawn a sock. (pete is empty.)" if empty else "pawn a sock. $1."))
				var license_owned: bool = inventory.count_records("license") > 0
				opts.append(_option("sell_license", "sell license plate. (pete is empty.)" if empty else ("sell license plate. $20." if license_owned else "ask about plates."), license_owned, "missing_license"))
				opts.append(_option("buy_food", "buy food. $3. (canned. unmarked.)" if cash >= 3 else "food is $3.", cash >= 3, "insufficient_cash"))
				var junk_owned: bool = inventory.count_records("junk") > 0
				opts.append(_option("sell_junk", "sell junk. (pete is empty.)" if empty else ("sell junk. $1 each." if junk_owned else "ask about junk."), junk_owned, "missing_junk"))
				var torch_stocked: bool = host.p.rank >= 3 or _flag("peteTorchStocked")
				if torch_stocked and not _flag("peteTorchSold") and not inventory.owns_tool("propane_torch"):
					opts.append(_option("buy_torch", "buy the propane torch. $80." if cash >= 80 else "the propane torch is $80. you don't have it.", cash >= 80, "insufficient_cash"))
				elif host.p.rank >= 3 and _flag("peteTorchSold"):
					opts.append(_option("torch_again", "ask about the torch again."))
				if not inventory.owns_tool("crowbar"):
					opts.append(_option("buy_crowbar", "buy the crowbar. $35. (municipal.)" if cash >= 35 else "the crowbar is $35. you don't have it.", cash >= 35, "insufficient_cash"))
				if host.s.flags.get("peteToolLocker") in ["propane_torch", "crowbar"]:
					opts.append(_option("swap_tools", "swap tools. pete is holding %s." % ("the crowbar" if host.s.flags.peteToolLocker == "crowbar" else "the torch")))
				if scrap >= 25 and _loan_day() != int(host.s.day):
					opts.append(_option("loan", "ask pete for $50. (he likes you.)"))
	opts.append(_option("leave", "leave."))
	return opts


func open(id: String) -> Dictionary:
	var reason: String = _talk_reason(id)
	if not reason.is_empty(): return _reject(reason)
	var options: Array[Dictionary] = _options(id)
	var ids: Array[String] = []
	for option: Dictionary in options: ids.append(option.id)
	var opened: Dictionary = session.begin(id, ids)
	if not opened.ok: return opened
	if id == "pete" and host.p.rank >= 3: host.s.flags.peteTorchStocked = true
	var tracked: Array = host.definition("src/data/catalogs.js", "VENDOR_FLOATER_IDS", [])
	if tracked.has(id):
		if not host.s.metVendors.has(id):
			host.s.metVendors.append(id)
			host.emit_event("save_requested")
		var intro: Dictionary = host.s.quests.get("intro_tony", {})
		if id == "tony" and intro.get("available", false) and not intro.get("done", false):
			intro.done = true
			host.p.cred += 1
			host.s.quests.intro_smoke.available = true
			host.emit_event("quest_completed", {"id":"intro_tony"})
			_toast("he charges ten dollars. that is the price.\nhe does not negotiate. sometimes he does.", 3400)
	var memory: RefCounted = _memory_ref.get_ref() if _memory_ref != null else null
	if memory != null: memory.bother(id)
	host.s.mode = "dialogue"
	return {"ok":true, "token":opened.token, "vendor":id, "title":TITLES[id], "text":_text(id), "options":options}


func _text(id: String) -> String:
	match id:
		"tony":
			var lines: Array[String] = ["what.", "$10. you know the number.", "you again. of course.", "three coats. ten dollars. simple math."]
			return lines[host.random_index(lines.size())] + "\n\ntony does not blink. tony is wearing three coats." + ("\nhe looks at your hat once. then twice. then not again." if _rock_price() < 10 else "")
		"pete":
			return "pete looks up. pete looks back down.\n'pete is full.\npete does not need your things.'" if host.p.faction.scrap <= -10 else "one second. eating.\npete is eating a hot pocket. behind glass."
		"yuri":
			return "what you bring, idiot." + ("\nthe shed is empty.\nthe shed could be yours." if host.p.faction.scrap >= 5 and not _flag("scrapHideoutOwned") else "")
	return ""


func close() -> void:
	session.close()
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"


func select(token: Variant, action_id: String) -> Dictionary:
	var selected: Dictionary = session.consume(token, action_id)
	if not selected.ok:
		if selected.reason not in ["stale_session", "replaced_state"] and host != null and host.s.mode == "dialogue": host.s.mode = "playing"
		return selected
	var vendor: String = selected.target
	var reason: String = _talk_reason(vendor)
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
	if not reason.is_empty(): return _reject(reason)
	var current: Dictionary = {}
	for option: Dictionary in _options(vendor):
		if option.id == action_id: current = option
	if current.is_empty(): return _reject("action_unavailable")
	if not current.enabled: return _reject(current.reason)
	if action_id == "leave": return {"ok":true, "vendor":vendor, "action":action_id}
	var result: Dictionary
	match vendor:
		"tony": result = _tony(action_id)
		"pete": result = _pete(action_id)
		"yuri": result = _yuri(action_id)
		_: return _reject("unknown_vendor")
	if result.ok:
		result.vendor = vendor; result.action = action_id
		host.emit_event("vendor_action", result)
	return result


func _reject(reason: String, line: String = "") -> Dictionary:
	if host != null:
		if reason == "shop_closed": line = "pete is sleeping inside.\n'we open at 6.'"
		if not line.is_empty(): _toast(line)
	return {"ok":false, "reason":reason}


func _toast(line: String, duration: int = 2200) -> void:
	host.emit_event("toast", {"text":line, "duration_ms":duration})


func _feed(line: String, author: String = "@crackheadcent") -> void:
	host.emit_event("feed", {"text":line, "author":author})


func _done(save: bool = true, sound: String = "coin") -> Dictionary:
	if not sound.is_empty(): host.emit_event("sound", {"id":sound})
	if save: host.emit_event("save_requested")
	return {"ok":true}


func _tony(action: String) -> Dictionary:
	match action:
		"buy_rock":
			var price: int = _rock_price()
			host.p.cash -= price; host.p.rocks += 1
			host.p.tonyOffenses = maxi(0, int(host.p.tonyOffenses) - 1)
			host.s.counters.rocksBought += 1
			if host.s.counters.rocksBought >= 50: host.unlock_achievement("tonys_worst")
			host.apply_rep({"street":1})
			if not host.s.quests.first_rock.done:
				host.s.quests.first_rock.done = true
				host.emit_event("quest_completed", {"id":"first_rock"})
			_toast("- $%d\n+ 1 rock" % price + ("\n(the crown got you a discount.\nhe is not happy about it.)" if price < 10 else ""))
			return _done()
		"short":
			var next_offense: int = int(host.p.tonyOffenses) + 1
			if next_offense >= 3 and not _start_boss(): return _reject("boss_unavailable")
			host.p.cash -= 5; host.p.tonyOffenses = next_offense
			_toast("tony stares. takes the $5. does not give a rock.\nyou now owe a kind of debt." if next_offense < 3 else "tony's eye twitches. he remembers.\nthe boss fight will come.")
			return _done(true, "")
		"challenge":
			if not _start_boss(): return _reject("boss_unavailable")
			_toast("tony tears off his coat. then another coat.\nthen a third coat.")
			return _done(false, "")
		"negotiate":
			_toast("tony explains, slowly, that he does not negotiate.\nhe is, in fact, negotiating right now.\n(this changes nothing.)")
			return _done(false, "")
	return _reject("unknown_action")


func _yuri(action: String) -> Dictionary:
	match action:
		"sell_copper", "sell_all_copper":
			var sold: int = int(host.p.copper) if action == "sell_all_copper" else 1
			var pay: int = sold * (28 if host.p.faction.scrap >= 10 else 25)
			host.p.copper -= sold; host.p.cash += pay
			host.apply_rep({"scrap":mini(5, sold)})
			_toast("- %d pure copper\n+ $%d" % [sold, pay])
			return _done()
		"rent_shed":
			host.p.cash -= 150; host.s.flags.scrapHideoutOwned = true
			host.apply_rep({"scrap":2})
			_toast("- $150\nyuri tosses you a bent key.\n'shed. back corner.\ndon't bring problems.'", 3600)
			_feed("got a key today. it bent in the pocket.")
			return _done(true, "")
		"brutus":
			_toast("yuri does not look up.\n'BRUTUS REMEMBER. you know what you did.'\n(you do not.)")
			return _done(false, "")
		"dog":
			var state: String = str(host.s.quests.get("scrap_dog", {}).get("state", "idle"))
			var line: String = "yuri does not look up.\n'the dog. is the dog.\nthe dog is fine.'"
			if state == "fed": line = "yuri does not look up.\n'somebody fed the dog.\nthe dog is no different.'\n(yuri pauses. is different.)"
			elif state == "freed": line = "yuri looks up.\n'the dog is gone.'\nhe looks back down.\n'good for the dog.'"
			_toast(line)
			return _done(false, "")
	return _reject("unknown_action")


func _pete(action: String) -> Dictionary:
	if action in ["sell_copper", "sock", "sell_license", "sell_junk"]:
		if _pete_room() <= 0: return _reject("pete_empty", EMPTY_LINE)
		var rate: int = 17 if host.p.faction.scrap >= 10 else 15
		var want: int = rate if action == "sell_copper" else (20 if action == "sell_license" else (inventory.count_records("junk") if action == "sell_junk" else 1))
		var pay: int = mini(want, _pete_room())
		if pay <= 0: return _reject("missing_item")
		match action:
			"sell_copper":
				host.p.copper -= 1
				host.apply_rep({"scrap":1})
				_toast("pete weighs it for 11 minutes.\n- 1 pure copper\n+ $%d" % pay + ("\npete is almost empty." if pay < rate else ""), 2800)
			"sock": _toast("+ $%d\n(it is wet.)" % pay)
			"sell_license":
				inventory.remove_all("license")
				host.apply_rep({"scrap":1})
				_toast("+ $%d" % pay + ("\npete is almost empty." if pay < 20 else "\n(do not ask where it came from.)"))
			"sell_junk":
				inventory.remove_records("junk", pay)
				_toast("- %d junk\n+ $%d" % [pay, pay] + ("\npete is almost empty." if pay < want else "\npete weighs each piece. it takes a while."), 2800)
		host.p.cash += pay
		host.s.counters.peteCashToday = int(host.s.counters.get("peteCashToday", 0)) + pay
		host.s.counters.peteSold = int(host.s.counters.get("peteSold", 0)) + 1
		return _done(action != "sock")
	match action:
		"buy_food":
			if not inventory.append_item("food", "a can of food (unmarked)"): return _reject("invalid_inventory")
			host.p.cash -= 3
			host.s.counters.peteSold = int(host.s.counters.get("peteSold", 0)) + 1
			_toast("- $3\n+ a can of food (unmarked).\npete keeps eating his hot pocket.", 2400)
			return _done()
		"buy_torch", "buy_crowbar":
			var torch: bool = action == "buy_torch"
			host.p.cash -= 80 if torch else 35
			var displaced: Variant = host.equip_tool("propane_torch" if torch else "crowbar")
			if torch:
				host.s.flags.peteTorchSold = true
				_toast("- $80\n+ a propane torch (dented)\npete does not explain where he got it.\n(equipped.)" + ("\nthe crowbar goes behind the glass.\nyou can cook or you can pry. not both." if displaced != null else ""), 4200)
				_feed("bought a torch off pete. pete is eating.")
			else:
				_toast("- $35\n+ a crowbar (municipal)\nit says PROPERTY OF. the rest wore off.\n(equipped.)" + ("\nthe torch goes behind the glass.\nyou can pry or you can cook. not both." if displaced != null else ""), 4200)
				_feed("bought a crowbar off pete. for projects.")
			return _done()
		"swap_tools":
			var swap: Dictionary = inventory.swap_locker()
			if not swap.ok: return swap
			var held_name: String = "the crowbar" if swap.held == "crowbar" else "the torch"
			var tension: String = "pete does not explain the service."
			if swap.returned != null:
				tension = "the torch goes behind the glass.\ntonight you pry. nothing cooks." if swap.held == "crowbar" else "the crowbar goes behind the glass.\ntonight you cook. nothing pries."
			_toast("pete slides %s across.\n%s\nno money moves." % [held_name, tension], 3600)
			return _done(true, "pickup")
		"loan":
			host.p.cash += 50; host.s.flags.scrapLoanDay = host.s.day
			host.p.cred = maxi(0, int(host.p.cred) - 1)
			_toast("pete looks at you for 11 minutes.\nthen counts out fifty.\n+ $50\n'pete remembers.'", 3800)
			_feed("pete handed someone fifty. pete does not hand out money.", "@blocklog")
			return _done(true, "")
		"torch_again":
			_toast("'sold the one.\ngo find your own.'\npete is still eating.", 2400)
			return _done(false, "")
	return _reject("unknown_action")
