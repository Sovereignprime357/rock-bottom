class_name RockBottomQuestDialogue
extends RefCounted
## Five linked source conversations and their crown/package lifecycle.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const IDS := ["barb","dave","stripe","conductor","pigeon"]
const TITLES := {"barb":"BAGGIE BARB","dave":"CHATTY DAVE","stripe":"STRIPE","conductor":"THE CONDUCTOR","pigeon":"THE PIGEON KING"}
const BLAME := "she looks up. her eyes are dry and the lashes are stuck.\n'fourteen across. five letters. begins with a B.\nit was BLAME.\nit's always BLAME.'\nshe looks back down."
const DELIVERY := "the conductor unfolds the package without looking at it.\n'stripe's name. stripe's money.\nyou are stripe's leg.\nit is monday.'"
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _memory_ref: WeakRef
var _combat_ref: WeakRef
var _boss_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var session: RefCounted
var _zone_session: RefCounted
var _page: String = ""
var _zone_token: bool = false
var _extra: String = ""
var _package_text: String = ""
var _package_exit: String = "leave"

func _init(owner: RefCounted, spatial: Object, memory: RefCounted = null, combat: RefCounted = null, bosses: RefCounted = null) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null
	_memory_ref = weakref(memory) if memory != null else null
	_combat_ref = weakref(combat) if combat != null else null
	_boss_ref = weakref(bosses) if bosses != null else null
	inventory = Inventory.new(owner); session = Session.new(owner,spatial)
	_zone_session = Session.new(owner,spatial,&"can_use_zone")
	owner.register_state_normalizer("crownPickup",normalize_crown)

static func normalize_crown(raw: Variant) -> Variant:
	if not raw is Dictionary or not raw.get("collected") is bool: return null
	for key: String in ["x","y"]:
		if not (raw.get(key) is float or raw.get(key) is int) or not is_finite(float(raw[key])): return null
	if raw.x < 0 or raw.y < 0 or raw.x > 8600 or raw.y > 5600: return null
	return {"x":float(raw.x),"y":float(raw.y),"collected":raw.collected}
func _dependency(reference: WeakRef, method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func supports(id: String) -> bool: return id in IDS
func _actor(id: String) -> Dictionary:
	if host != null:
		for body: Dictionary in host.npcs:
			if body.get("id") == id: return body
	return {}
func _center(body: Dictionary) -> Vector2: return Vector2(float(body.x)+float(body.w)*0.5,float(body.y)+float(body.h)*0.5)
func _flag(key: String) -> bool: return host.s.flags.get(key,false) == true
func _reason(id: String, automatic: bool = false) -> String:
	if host == null: return "missing_owner"
	if not supports(id): return "unknown_resident"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if not automatic and host.s.get("bossKind","") == "kingdom": return "active_boss"
	var body := _actor(id)
	if body.is_empty() or body.get("dead",false): return "missing_resident"
	if host.player_center().distance_squared_to(_center(body)) >= 3600.0: return "out_of_reach"
	return ""
func _option(id: String, label: String, enabled: bool = true, reason: String = "unavailable") -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else reason}
func _done() -> Dictionary: return {"ok":true,"closed":true}
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String, ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _save() -> void: host.emit_event("save_requested")
func _quest(id: String, title: String) -> void:
	host.s.quests[id].done = true; host.emit_event("quest_completed",{"id":id})
	_toast("· QUEST COMPLETE ·\n"+title); _sound("rankUp")
func _crossword() -> bool:
	return host.s.quests.barb_crossword.get("available",false) and not host.s.quests.barb_crossword.done and _flag("daveHasCrossword") and not _flag("hasCrossword")
func _fence_price(index: int) -> int: return host.vendor_price(6 if index < 3 else (4 if index < 6 else 2))

func _options(id: String, page: String, opening: bool = false) -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	var cash: int = host.p.cash
	match page:
		"ransom":
			if _crossword():
				opts.append(_option("pay_ransom","pay $20 ransom." if cash >= 20 else "you don't have $20.",cash >= 20,"insufficient_cash"))
				opts.append(_option("fight_dave","fight him."))
		"barb_return","barb_answer": pass
		"package_offer":
			if not host.s.quests.stripe_package.done and not _flag("stripeBetrayed") and not _flag("hasStripePackage"):
				opts.append(_option("take_package","take it.")); opts.append(_option("pass_package","pass. (offer holds.)"))
			return opts
		"coop":
			if host.p.stripeLoyalty >= 5 and not _flag("stripeBetrayed") and not _flag("hasStripePackage"):
				opts.append(_option("agree_coop","agree. ride with stripe.")); opts.append(_option("decline_coop","decline. (the deal expires.)"))
			return opts
		"crown_offer":
			if not host.s.quests.pigeon_crown.done and not host.s.quests.pigeon_crown.get("available",false):
				opts.append(_option("accept_crown","accept the search.")); opts.append(_option("decline_crown","decline."))
			return opts
		"delivery": return [_option("leave","+$40 · +3 cred · leave.")]
		"main":
			match id:
				"barb":
					var remaining: int = maxi(0,6-int(host.s.counters.get("barbPacketsToday",0)))
					var one: int = host.vendor_price(5); var five: int = host.vendor_price(22)
					if remaining == 0: opts.append(_option("packets_closed","buy packets. (she is tired.)"))
					else:
						opts.append(_option("buy_one","buy 1 packet. $%d. (unmarked.)" % one if cash >= one else "a packet is $%d." % one,cash >= one,"insufficient_cash"))
						if remaining >= 5: opts.append(_option("buy_five","buy 5 packets. $%d. (bulk.)" % five if cash >= five else "5 packets is $%d." % five,cash >= five,"insufficient_cash"))
						else: opts.append(_option("bulk_closed","buy 5 packets bulk. (not today.)"))
					opts.append(_option("contents","ask what's in them."))
					var quest: Dictionary = host.s.quests.barb_crossword
					var available: bool = quest.get("available",false) or (opening and int(host.s.counters.get("barbVisits",0))+1 >= 2)
					if quest.done: opts.append(_option("answer","ask what 14 across was."))
					elif quest.get("available",false) and _flag("hasCrossword"): opts.push_front(_option("return_crossword","give barb her crossword back."))
					elif not available: opts.append(_option("clue","ask what 14 across is."))
				"dave":
					if _crossword(): opts.append(_option("demand","demand the saturday crossword."))
					if _actor("dave").get("asleep",false):
						opts.append(_option("pickpocket","pickpocket. (+$8)")); opts.append(_option("wake","wake him up."))
					else: opts.append(_option("listen","listen for a while. (-5 brain)"))
				"stripe":
					if _flag("stripeBetrayed"): opts.append(_option("apologize","try to apologize."))
					elif not _flag("hasStripePackage"):
						var buy: int = host.vendor_price(8); var fenced: int = host.s.counters.get("stripeFencedToday",0)
						var next: int = _fence_price(fenced)
						opts.append(_option("buy_rock","buy stripe's rock. $%d." % buy if cash >= buy else "you can't afford it.",cash >= buy,"insufficient_cash"))
						if fenced >= 10: opts.append(_option("fence_closed","sell rocks to stripe. (closed today.)"))
						else:
							opts.append(_option("fence_one","sell 1 rock to stripe. $%d." % next if host.p.rocks >= 1 else "you have no rocks to sell.",host.p.rocks >= 1,"insufficient_rocks"))
							opts.append(_option("fence_bulk","sell rocks bulk. ($%d/rock, gating.)" % next if host.p.rocks >= 3 else "stripe wants 3+ for a bulk deal.",host.p.rocks >= 3,"insufficient_rocks"))
						var quest: Dictionary = host.s.quests.stripe_package
						var visits: int = int(host.s.counters.get("stripeVisits",0))+(1 if opening else 0)
						if not quest.done and not quest.get("available",false) and visits >= 3: opts.append(_option("package","stripe leans in. listen."))
						elif quest.get("available",false) and not quest.done: opts.append(_option("package","ask about the package again."))
						opts.append(_option("about","ask stripe about the corner." if host.p.stripeLoyalty >= 5 else "ask stripe about himself."))
				"conductor":
					opts.append(_option("sell_copper","sell 3 PURE COPPER. $90.",host.p.copper >= 3,"insufficient_copper"))
					opts.append(_option("train","ask when the train arrives."))
				"pigeon":
					opts.append(_option("secret","pay $2 for a secret." if cash >= 2 else "you don't have $2.",cash >= 2,"insufficient_cash"))
					var quest: Dictionary = host.s.quests.pigeon_crown
					if not quest.done and not quest.get("available",false) and int(host.s.counters.get("pigeonVisits",0))+(1 if opening else 0) >= 2: opts.append(_option("crown","ask about the crown."))
	opts.append(_option("leave","leave."))
	return opts

func open(id: String) -> Dictionary: return _show(id,"main",true)
func _show(id: String, page: String, opening: bool = false) -> Dictionary:
	close()
	var reason := _reason(id,page == "delivery")
	if not reason.is_empty(): return _fail(reason)
	var options := _options(id,page,opening)
	var ids: Array[String] = []
	for option: Dictionary in options: ids.append(option.id)
	var started: Dictionary = session.begin(id,ids)
	if not started.ok: return started
	_page = page
	if opening:
		var tracked: Array = host.definition("src/data/catalogs.js","VENDOR_FLOATER_IDS",[])
		if id in tracked and not host.s.metVendors.has(id): host.s.metVendors.append(id); _save()
		var memory: Object = _dependency(_memory_ref,&"bother")
		if memory != null: memory.bother(id)
		if id == "stripe" and _actor(id).get("isAlly",false):
			close(); _toast("'this is happening.'\nstripe does not stop walking."); return _done()
		_opening(id)
	host.s.mode = "dialogue"
	return {"ok":true,"token":started.token,"actor":id,"page":page,"title":TITLES[id],"text":_text(id,page),"options":options}
func close() -> void:
	session.close(); _zone_session.close(); _page = ""; _zone_token = false
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
func _opening(id: String) -> void:
	_extra = ""
	if id == "barb":
		host.s.counters.barbVisits = int(host.s.counters.get("barbVisits",0))+1
		if host.s.get("barbAside",false):
			var asides: Array[String] = ["\n(she taps the pen.)\n'pinky's salt is salt. just salt.\nmine has more salt.'","\n(she does not look up.)\n'i hear pinky undercuts.\nhe will. eventually. cut himself.'","\n(the dauber moves an inch.)\n'pinky calls it amore. it is not.'"]
			_extra = asides[host.random_index(asides.size())]; host.s.barbAside = false
		var quest: Dictionary = host.s.quests.barb_crossword
		if not quest.done and not quest.get("available",false) and host.s.counters.barbVisits >= 2:
			quest.available = true; host.s.flags.daveHasCrossword = true
			_extra += "\n(her hand pauses over the puzzle.)\n'somebody took my saturday.\ni need it back. i am not well without it.'"; _save()
	elif id == "stripe": host.s.counters.stripeVisits = int(host.s.counters.get("stripeVisits",0))+1
	elif id == "pigeon": host.s.counters.pigeonVisits = int(host.s.counters.get("pigeonVisits",0))+1

func _text(id: String, page: String) -> String:
	match page:
		"ransom": return "dave looks at you up and down.\n'$20 or fight.\nor walk. that is a third thing.'"
		"barb_answer": return BLAME
		"barb_return": return "she takes it. for the first time in years "+BLAME.replace("she looks up. her eyes","she looks up.\nher eyes")+"\n\n+ 1 packet (free.)"
		"package_offer": return "stripe got a package.\ngoes to the conductor in the train yard.\nstripe's name. stripe's money.\ndon't open it.\ndon't."
		"coop": return "yo. we should team up.\ntake tony's corner.\nyou get tuesdays and thursdays.\ni get the rest.\nyou ride at my side. on me. with me."
		"crown_offer": return "the crown fell.\nthe pigeons grieve.\nhe says where it might be.\n\nlast seen: "+str(pick_crown_spot().get("where",""))+"."
		"delivery": return DELIVERY
	match id:
		"barb":
			var lines: Array[String] = ["she does not look up. she is doing the crossword.","her cart has three packets and a romance novel.","she hums. it is not a song.","she is, in fact, someone's grandma. somewhere.","the bingo dauber on the table has never been used for bingo."]
			return "what.\n"+lines[host.random_index(lines.size())]+_extra
		"dave": return "dave is asleep. his wallet is half out." if _actor(id).get("asleep",false) else "dave is explaining a theory about pigeons.\nthe theory has 17 parts."
		"stripe":
			if _flag("stripeBetrayed"): return "stripe knows.\nstripe has friends.\nstripe is patient.\nthe windbreaker is still."
			if _flag("hasStripePackage"): return "you have it.\nyou have not delivered it.\nthe conductor is in the train yard.\nhe does not move."
			return "$8 a rock. stripe got the deal.\nstripe is wearing a faded windbreaker."
		"conductor": return "the train is coming.\nit has always been coming.\nit will never be here."
		"pigeon":
			var tail: String = ""
			var quest: Dictionary = host.s.quests.pigeon_crown
			if not quest.done and not quest.get("available",false) and host.s.counters.pigeonVisits >= 2: tail = "\nhe regards you.\nhis crown is missing.\nit has been missing for some time."
			elif quest.get("available",false) and not quest.done: tail = "\nhe has not blinked since you accepted.\nthe crown is still missing."
			elif quest.done: tail = "\nthe crown is back. the pigeons walk in formation now."
			return "one foot.\nunblinking.\nhe wants the bread."+tail
	return ""

func select(token: Variant, action: String) -> Dictionary:
	var page: String = _page
	var zone: bool = _zone_token
	var accepted: Dictionary = _zone_session.consume(token,action) if zone else session.consume(token,action)
	if not accepted.ok:
		if accepted.reason not in ["stale_session","replaced_state"] and host != null and host.s.mode == "dialogue": host.s.mode = "playing"
		return accepted
	_page = ""; _zone_token = false
	if host.s.mode == "dialogue": host.s.mode = "playing"
	if zone: return _done() if action == _package_exit else _fail("action_unavailable")
	var id: String = accepted.target
	if page == "delivery": return _done()
	var reason := _reason(id)
	if not reason.is_empty(): return _fail(reason)
	if id == "stripe" and _actor(id).get("isAlly",false): return _fail("action_unavailable")
	var selected: Dictionary = {}
	for option: Dictionary in _options(id,page):
		if option.id == action: selected = option; break
	if selected.is_empty(): return _fail("action_unavailable")
	if not selected.enabled: return _fail(selected.reason)
	if action == "leave": return _done()
	var result: Dictionary
	match id:
		"barb": result = _barb(action)
		"dave": result = _dave(action)
		"stripe": result = _stripe(action)
		"conductor": result = _conductor(action)
		"pigeon": result = _pigeon(action)
		_: return _fail("unknown_resident")
	if result.ok: host.emit_event("quest_dialogue_action",{"actor":id,"action":action})
	return result

func _barb(action: String) -> Dictionary:
	match action:
		"packets_closed": _toast("she's tired.\ncome back tomorrow.\nshe has 14 across to think about.",3600)
		"bulk_closed": _toast("she taps the pen.\n'i'm not weighing five out tonight.\ncome back tomorrow.'",3200)
		"buy_one","buy_five":
			var amount: int = 1 if action == "buy_one" else 5
			var cost: int = host.vendor_price(5 if amount == 1 else 22)
			var memory: Object = _dependency(_memory_ref,&"record")
			if memory == null: return _fail("memory_unavailable")
			host.p.cash -= cost; host.p.supplies += amount
			host.s.counters.barbPacketsToday = int(host.s.counters.get("barbPacketsToday",0))+amount
			memory.record("laundromat","buy","barb_single" if amount == 1 else "barb_bulk")
			var tail: String = "\nshe stops writing.\nshe's tired.\ncome back tomorrow." if host.s.counters.barbPacketsToday >= 6 else ""
			_toast("- $%d\n+ 1 packet (unmarked)\nshe does not look up." % cost+tail if amount == 1 else "- $%d\n+ 5 packets\nshe writes '14 across' in pen." % cost+tail)
			_sound("coin"); _save()
		"contents": _toast("she does not look up.\n'salt.'\nyou both know.\nyou both agree to not.")
		"answer": return _show("barb","barb_answer")
		"return_crossword":
			# Preflight the new receipt capability before paying the once-only quest reward.
			var menu: Dictionary = _show("barb","barb_return")
			if not menu.ok: return menu
			host.s.flags.hasCrossword = false; inventory.remove_all("crossword"); host.p.supplies += 1
			_quest("barb_crossword","BARB'S MISSING CROSSWORD"); host.unlock_achievement("seven_across")
			host.apply_rep({"street":1}); _sound("coin"); _save()
			return menu
		"clue":
			var lines: Array[String] = ["'a flightless bird.' 3 letters.\nit is EMU. it is always EMU.","'a man with a plan.' 4 letters.\nshe writes BARB.\nyou do not correct her.","'something you regret.' 11 letters.\nshe does not write anything.\nshe looks at you. briefly.","'opposite of clean.' 5 letters.\nshe writes BARB again."]
			_toast(lines[host.random_index(lines.size())],3800)
	return _done()

func _give_crossword(paid: bool) -> void:
	host.s.flags.daveHasCrossword = false; host.s.flags.hasCrossword = true
	inventory.append_item("crossword","barb's saturday crossword")
	_toast("- $20\n+ saturday crossword\nhe pockets your cash.\nhe is whistling." if paid else "dave does the math.\nhe hands you a folded newspaper.\n'i thought she wouldn't notice.\nshe did.'\n+ saturday crossword",2200 if paid else 4200)
	_save()
func _dave(action: String) -> Dictionary:
	var body: Dictionary = _actor("dave")
	match action:
		"demand":
			if host.p.cred >= 3: _give_crossword(false)
			else: return _show("dave","ransom")
		"pay_ransom": host.p.cash -= 20; _give_crossword(true)
		"fight_dave":
			var combat: Object = _dependency(_combat_ref,&"aggro")
			if combat == null: return _fail("combat_unavailable")
			if combat.aggro("dave") != true: return _fail("combat_unavailable")
			body.asleep = false; _toast("dave is hostile now.\nhe still has the crossword.\nbeat him until it falls out.")
		"pickpocket":
			if host.random_float() < 0.7: host.p.cash += 8; _toast("+ $8\ndave keeps sleeping."); _sound("coin")
			else:
				body.asleep = false; body.hostile = true; body.aggro = true; host.p.wanted = mini(3,int(host.p.wanted)+1)
				_toast("DAVE WAKES UP.\nyou sprint. he chases.")
		"wake": body.asleep = false; _toast("dave wakes up. he is talking immediately.")
		"listen": host.p.brain = maxf(0.0,float(host.p.brain)-5.0); _toast("- 5 brain\nyou know more about pigeons now.\nthis was not free.")
	return _done()

func _fence_rep() -> void:
	host.apply_rep({"street":1})
	var current: int = int(host.s.counters.get("stripeSpiritualDayHits",0)) if int(host.s.counters.get("stripeSpiritualDayHitsDay",0)) == int(host.s.day) else 0
	if current < 3:
		host.apply_rep({"spiritual":-1}); host.s.counters.stripeSpiritualDayHits = current+1
		host.s.counters.stripeSpiritualDayHitsDay = host.s.day
func _stripe(action: String) -> Dictionary:
	match action:
		"apologize": _toast("stripe does not blink.\n(this is not tony's not-blinking.\nthis is different.)")
		"buy_rock":
			var cost: int = host.vendor_price(8)
			host.p.cash -= cost; host.p.stripeLoyalty += 1
			if host.random_float() < 0.4:
				_toast("- $%d\n(it is soap. you keep it. it is soap.)" % cost)
				inventory.append_item("soap","a small bar of soap"); host.p.tonyOffenses = maxi(0,int(host.p.tonyOffenses)-1)
			else: host.p.rocks += 1; _toast("- $%d\n+ 1 rock\n(yeah it's probably real.)" % cost); _sound("coin")
			host.apply_rep({"street":1})
			if host.p.stripeLoyalty == 5: _toast("stripe nods slowly.\nhe sees you.\nhe has a proposal.",3000)
			_save()
		"fence_closed": _toast("stripe will not buy from you today.\ntomorrow.",3000)
		"fence_one","fence_bulk":
			var sold: int = 0; var total: int = 0
			var degraded_one: bool = false; var degraded_two: bool = false; var closed: bool = false
			while host.p.rocks > 0 and int(host.s.counters.get("stripeFencedToday",0)) < 10:
				var before: int = host.s.counters.get("stripeFencedToday",0)
				total += _fence_price(before); sold += 1; host.p.rocks -= 1; host.s.counters.stripeFencedToday = before+1
				_fence_rep()
				if before+1 == 4: degraded_one = true
				if before+1 == 7: degraded_two = true
				if before+1 == 10: closed = true
				if action == "fence_one": break
			host.p.cash += total; host.p.lifetime.rocksFenced = int(host.p.lifetime.get("rocksFenced",0))+sold
			var tail: String = ""
			if closed: tail = "\nstripe will not buy from you today.\ntomorrow."
			elif degraded_two: tail = "\nstripe is done.\nstripe is done with rocks."+("\ngo away." if action == "fence_one" else "")
			elif degraded_one: tail = "\nstripe is taking less today.\nstripe is taking what stripe takes."
			if action == "fence_one":
				if tail.is_empty(): tail = "\nstripe pockets it.\nit will be $%d by morning." % host.vendor_price(8)
				_toast("- 1 rock\n+ $%d" % total+tail)
			else: _toast("- %d rocks\n+ $%d\nstripe stacks them with his.\nthe stack is now his stack." % [sold,total]+tail,4200)
			_sound("coin"); _save()
		"package": return _show("stripe","package_offer")
		"take_package":
			host.s.quests.stripe_package.available = true; host.s.flags.hasStripePackage = true
			inventory.append_item("stripe_package","stripe's sealed package")
			_toast("+ stripe's package\nbrown paper. greasy in one corner.\ntake it to the conductor at the train yard.\ndon't.",4000); _save()
		"pass_package": _toast("'next time.'\nstripe shrugs.\nthe windbreaker stays still.")
		"about":
			if host.p.stripeLoyalty >= 5: return _show("stripe","coop")
			_toast("'stripe is stripe.'\nhe stares.\nthe windbreaker rustles.")
		"agree_coop":
			var bosses: Object = _dependency(_boss_ref,&"start_coop")
			if bosses == null or bosses.start_coop() != true: return _fail("boss_unavailable")
		"decline_coop": _toast("stripe nods.\nhe will not ask again.\nthe air shifts."); host.p.stripeLoyalty = -1
	return _done()

func _conductor(action: String) -> Dictionary:
	if action == "train": _toast("the conductor does not answer.\nthe conductor is the answer.")
	else:
		host.p.copper -= 3; host.p.cash += 90
		_toast("- 3 pure copper\n+ $90\nthe conductor nods at no one."); _sound("coin")
		if not host.s.quests.conductor.done: _quest("conductor","THE CONDUCTOR'S BARGAIN")
		_save()
	return _done()

func _pigeon(action: String) -> Dictionary:
	match action:
		"secret":
			var memory: Object = _dependency(_memory_ref,&"record")
			if memory == null: return _fail("memory_unavailable")
			host.p.cash -= 2; host.s.counters.pigeonTrade = int(host.s.counters.get("pigeonTrade",0))+2
			if host.s.counters.pigeonTrade >= 20: host.unlock_achievement("one_foot")
			memory.record("park","buy","pigeon_secret")
			var lines: Array[String] = ["the copper sings in b flat.\nyou are not crazy.","yuri is going home to a family.\nthis is information.","pete is on his lunch break. forever.","the possum has a route.\nyou are on it.","tony has, in fact, blinked. once. in 1994.","father o'malley is not real.\nhe is. but also not."]
			_toast(lines[host.random_index(lines.size())],4500)
		"crown": return _show("pigeon","crown_offer")
		"accept_crown":
			var spot: Dictionary = pick_crown_spot()
			if spot.is_empty(): return _fail("missing_crown_definition")
			host.s.quests.pigeon_crown.available = true
			host.s.crownPickup = {"x":spot.x,"y":spot.y,"collected":false}
			host.emit_event("quest_pickup_changed",{"id":"crown","position":Vector2(spot.x,spot.y)}); _save()
			_toast("the pigeons watch you leave.\nyou are on a route now.",3000)
		"decline_crown": _toast("the pigeons watch you leave.\nthey are not impressed.")
	return _done()

func pick_crown_spot() -> Dictionary:
	if host == null: return {}
	var spots: Array = host.definition("src/data/catalogs.js","CROWN_SPOTS",[])
	if spots.is_empty(): return {}
	var raw: Variant = host.s.flags.get("crownSpotIdx",-1)
	var index: int = -1
	if (raw is int or raw is float) and is_finite(float(raw)) and floor(float(raw)) == float(raw) and raw >= 0 and raw < spots.size(): index = int(raw)
	if index < 0: index = host.random_index(spots.size()); host.s.flags.crownSpotIdx = index
	return (spots[index] as Dictionary).duplicate(true)

func tick_before_pickups(dt_ms: float) -> bool:
	if host == null or host.s.mode != "playing" or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	var conductor := _actor("conductor")
	if not conductor.is_empty() and not conductor.get("dead",false):
		if host.player_center().distance_squared_to(_center(conductor)) < 6400.0:
			host.s.conductorWaitT = float(host.s.get("conductorWaitT",0.0))+dt_ms
			if host.s.conductorWaitT >= 60000.0: host.unlock_achievement("the_conductor_knows")
		else: host.s.conductorWaitT = 0.0
	return true

func collect_crown() -> bool:
	if host == null or host.s.mode != "playing": return false
	var pickup: Variant = normalize_crown(host.s.get("crownPickup"))
	if pickup == null or pickup.collected: return false
	if host.player_center().distance_squared_to(Vector2(pickup.x,pickup.y)) >= 324.0: return false
	var spatial: Object = _dependency(_spatial_ref,&"can_reach_target")
	if spatial == null or spatial.can_reach_target("quest:crown") != true: return false
	host.s.crownPickup.collected = true
	var equip: Dictionary = host.content.catalogs.equipment.pigeon_crown
	host.p.equip[equip.slot] = "pigeon_crown"; host.apply_equip_stats(); _sound("coin")
	_toast("· the crown ·\nit is heavier than it looks.\nthe pigeons stop walking. they watch.\n+ EQUIPPED · the pigeon king's crown",4500)
	if not host.s.quests.pigeon_crown.done:
		_quest("pigeon_crown","THE PIGEON KING'S LOST CROWN"); host.unlock_achievement("head_that_wears")
	host.emit_event("quest_pickup_changed",{"id":"crown","collected":true}); _save()
	return true

func tick_after_pickups() -> Dictionary:
	if host == null or host.s.mode != "playing": return {}
	collect_crown()
	if not _flag("hasStripePackage"): return {}
	var reason := _reason("conductor",true)
	if not reason.is_empty(): return {}
	var menu: Dictionary = _show("conductor","delivery")
	if not menu.ok: return {}
	host.s.flags.hasStripePackage = false; inventory.remove_all("stripe_package")
	if not host.s.quests.stripe_package.done:
		_quest("stripe_package","STRIPE'S PACKAGE"); host.p.cash += 40; host.p.cred += 3; host.unlock_achievement("exact_change")
	_sound("coin"); _save()
	host.emit_event("package_delivered")
	return menu

func open_package() -> Dictionary:
	if host == null: return _fail("missing_owner")
	if host.s.mode not in ["playing","dialogue"] or host.s.get("bossKind","") == "kingdom": return _fail("unavailable")
	if not _flag("hasStripePackage"): return _fail("no_package")
	var in_block: bool = false
	var point: Vector2 = host.player_center()
	for zone: Dictionary in host.content.world.zones:
		if zone.id == "block": in_block = point.x >= zone.x and point.x <= zone.x+zone.w and point.y >= zone.y and point.y <= zone.y+zone.h; break
	if not in_block: return _fail("outside_block")
	close()
	var actions: Array[String] = ["leave","sprint"]
	var opened: Dictionary = _zone_session.begin("block",actions)
	if not opened.ok: return opened
	var roll: float = host.random_float()
	host.s.flags.hasStripePackage = false; inventory.remove_all("stripe_package")
	host.unlock_achievement("what_s_in_the_box"); host.s.quests.stripe_package.done = true; host.s.flags.stripeBetrayed = true
	_package_exit = "leave"
	if roll < 0.35:
		host.p.rocks += 5; _sound("coin")
		_package_text = "you tear it open.\nfive rocks. wrapped in newsprint.\nthe newsprint is from 2003.\n\n+ 5 rocks\nstripe knows. stripe will know."
	elif roll < 0.65:
		inventory.append_item("soap","a small bar of soap"); inventory.append_item("soap","a small bar of soap")
		_package_text = "you tear it open.\ntwo bars of soap.\nthey smell like cherries.\n\n+ 2 soaps\nstripe knows. stripe will know."
	elif roll < 0.90:
		host.p.weapon = "knife"
		var weapon: Dictionary = host.content.catalogs.weapons.knife
		_toast("+ "+str(weapon.n)+"\n(equipped.)")
		host.emit_event("feed",{"text":"picked up "+str(weapon.n)+". things are escalating.","author":"@crackheadcent"})
		_package_text = "you tear it open.\nit is a knife.\nthe handle is wrapped in electrical tape.\n\n+ a knife\nstripe knows. stripe will know."
	else:
		host.p.wanted = mini(3,int(host.p.wanted)+2); _sound("copSiren"); _package_exit = "sprint"
		_package_text = "you tear it open.\nit is a wire.\na small bag of nothing taped to it.\n\nthe package was bait.\nwanted +2.\nstripe knows. stripe will know."
	_save(); _page = "package_result"; _zone_token = true; host.s.mode = "dialogue"
	return {"ok":true,"token":opened.token,"actor":"block","page":_page,"title":"THE PACKAGE","text":_package_text,"options":[_option(_package_exit,_package_exit+".")]}
