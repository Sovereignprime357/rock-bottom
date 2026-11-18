class_name RockBottomStreetDialogue
extends RefCounted
## Literal street transactions. Travel, feed and rhythm remain single external owners.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const IDS := ["pinky","cubscout","jogger","dogwalker","busker","horsecop","vapelord","pothole","mayorscousin","phoneguy","laundromat_lady","meter_maid","food_truck","priests_son","karaoke"]
const TITLES := {"pinky":"PINKY POLENTA","cubscout":"CUBSCOUT","jogger":"JOGGER","dogwalker":"DOG WALKER","busker":"BUSKER","horsecop":"HORSE COP","vapelord":"THE VAPE LORD","pothole":"A POTHOLE","mayorscousin":"THE MAYOR'S COUSIN","phoneguy":"THE PHONE GUY","laundromat_lady":"LAUNDROMAT LADY","meter_maid":"METER MAID","food_truck":"FOOD TRUCK GUY","priests_son":"THE PRIEST'S SON","karaoke":"KARAOKE MIKE"}
const TEXT := {
	"cubscout":"popcorn?\n$8 a tin.\nhis mom is in the car.",
	"jogger":"heart rate 142.\nshe does not stop. she is talking through it.",
	"dogwalker":"paisley. no. paisley LEAVE IT.\npaisley is a small dog made of fur.",
	"busker":"he is playing a song he wrote.\nit has no chorus.\nhe has a guitar case open at his feet.",
	"horsecop":"a cop on horseback nods at you.\nthe horse also nods.\ndisturbing levels of agreement.",
	"vapelord":"he is exhaling watermelon mist.\nhe trades in juice.\nhe has a small dragon on his back.\nthe dragon is also vaping.",
	"pothole":"the pothole says your full legal name.\nyou did not give it your full legal name.",
	"mayorscousin":"he knows the mayor.\nhe is wearing a suit jacket.\nhe is not wearing pants.",
	"phoneguy":"he is on his phone.\nhe has been on his phone.\nhe sees you. he tweets about you.",
	"laundromat_lady":"she is folding the same shirt.\nshe has been folding the same shirt.\nthe shirt is hers, you think.",
	"meter_maid":"she is writing a ticket.\nfor what.\nfor existing in a designated zone.",
	"food_truck":"the truck says 'TACOS' in 4 fonts.\nthe truck has not moved since wednesday.\nit is wednesday.",
	"priests_son":"he is wearing a backwards cap.\nhe is the priest's son.\nthe priest does not acknowledge this.",
	"karaoke":"he holds a karaoke machine.\nit is just a machine. there is no microphone.\nhe sings without one."
}
var _host_ref: WeakRef
var _memory_ref: WeakRef
var _travel_ref: WeakRef
var _activities_ref: WeakRef
var _communications_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var session: RefCounted

func _init(owner: RefCounted,spatial: Object,memory: Object = null,travel: Object = null,activities: Object = null,communications: Object = null) -> void:
	_host_ref = weakref(owner)
	_memory_ref = weakref(memory) if memory != null else null
	_travel_ref = weakref(travel) if travel != null else null
	_activities_ref = weakref(activities) if activities != null else null
	_communications_ref = weakref(communications) if communications != null else null
	inventory = Inventory.new(owner); session = Session.new(owner,spatial)
func _dependency(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func supports(id: String) -> bool: return id in IDS
func _actor(id: String) -> Dictionary:
	if host != null:
		for body: Dictionary in host.npcs:
			if body.get("id") == id: return body
	return {}
func _reason(id: String) -> String:
	if host == null: return "missing_owner"
	if not supports(id): return "unknown_resident"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	var body := _actor(id)
	if body.is_empty() or body.get("dead",false): return "missing_resident"
	var center := Vector2(float(body.x)+float(body.w)*0.5,float(body.y)+float(body.h)*0.5)
	if host.player_center().distance_squared_to(center) >= 3600.0: return "out_of_reach"
	return ""
func _hated() -> bool: return host.p.faction.street <= -10
func _option(id: String,label: String,enabled: bool = true,reason: String = "insufficient_cash") -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else reason}
func _done() -> Dictionary: return {"ok":true,"closed":true}
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _feed(text: String,author: String) -> void: host.emit_event("feed",{"text":text,"author":author})
func _save() -> void: host.emit_event("save_requested")

func _options(id: String) -> Array[Dictionary]:
	var cash: int = host.p.cash
	var options: Array[Dictionary] = []
	match id:
		"pinky":
			if not _hated():
				var one: int = host.vendor_price(4); var five: int = host.vendor_price(18)
				options.append(_option("buy_one","buy 1 house cut packet. $%d." % one if cash >= one else "house cut is $%d." % one,cash >= one))
				options.append(_option("buy_five","buy 5 packets bulk. $%d." % five if cash >= five else "5 packets bulk is $%d." % five,cash >= five))
				if inventory.count_records("bus_pass") > 0: options.append(_option("use_pass","use the bus pass."))
				else: options.append(_option("buy_pass","buy a bus pass. $20." if cash >= 20 else "a bus pass is $20.",cash >= 20))
				options.append(_option("no_like","you no like?")); options.append(_option("cut","ask about the cut."))
		"cubscout":
			options.append(_option("popcorn","buy popcorn. $8." if cash >= 8 else "you don't have $8.",cash >= 8))
			options.append(_option("mom","ask if his mom knows about this."))
		"jogger": options.append(_option("dollar","ask for $1."))
		"dogwalker": options.append(_option("pet","pet paisley."))
		"busker":
			options.append(_option("tip","tip $1." if cash >= 1 else "you don't have $1.",cash >= 1))
			options.append(_option("song","request a different song."))
		"horsecop":
			options.append(_option("nod","nod back.")); options.append(_option("compliment","compliment the horse.")); options.append(_option("pet","try to pet the horse."))
		"vapelord":
			options.append(_option("pod","buy a pod. $6. (+10 brain)" if cash >= 6 else "you don't have $6.",cash >= 6)); options.append(_option("free","ask for a free hit."))
		"pothole": options.append(_option("argue","argue with the pothole.")); options.append(_option("throw","throw something in it."))
		"mayorscousin":
			options.append(_option("mayor","ask about the mayor.")); options.append(_option("favor","ask for a favor."))
			options.append(_option("bribe","bribe him. $5." if cash >= 5 else "you don't have $5.",cash >= 5))
		"phoneguy":
			options.append(_option("posting","ask what he's posting."))
			options.append(_option("content","give him content. $3. (+post)" if cash >= 3 else "you don't have $3.",cash >= 3))
		"laundromat_lady":
			options.append(_option("laundry","do a load of laundry. $2. (regen +12 hp)" if cash >= 2 else "need $2.",cash >= 2))
			options.append(_option("detergent","buy detergent. $5. (item)" if cash >= 5 else "detergent is $5.",cash >= 5))
			options.append(_option("why","ask why she is here."))
		"meter_maid":
			options.append(_option("meter","pay the meter. $2. (-1 wanted)" if cash >= 2 else "meters cost $2.",cash >= 2))
			options.append(_option("flirt","try to flirt."))
		"food_truck":
			options.append(_option("taco","buy a mystery taco. $4. (+20 hp · ?)" if cash >= 4 else "$4 minimum for hp.",cash >= 4))
			options.append(_option("horchata","buy a horchata. $8. (+30 brain)" if cash >= 8 else "horchata is $8.",cash >= 8))
			# The shipped source label has a rock check; disabled/action do not.
			options.append(_option("burrito","buy a 'special' burrito. $15. (+1 rock somehow)" if cash >= 15 and host.p.rocks < 3 else "specials are $15.",cash >= 15))
		"priests_son":
			options.append(_option("priest","ask about the priest."))
			options.append(_option("tic_tac","buy a real tic-tac. $10. (+1 rock — actually??)" if cash >= 10 else "specials run $10.",cash >= 10))
		"karaoke":
			options.append(_option("sing","sing a song. $5. (rhythm minigame)" if cash >= 5 else "karaoke is $5.",cash >= 5))
			options.append(_option("request","request a song."))
	options.append(_option("leave","leave."))
	return options
func _text(id: String) -> String:
	if id != "pinky": return TEXT[id]
	if _hated(): return "pinky steps back.\n'you smell like a snitch.\npinky no sell to a snitch.\nyou go barb. barb sell to snitch.'"
	var lines: Array[String] = ["buongiorno mi crackhead.","the cut is amore.","is fresh. from the house.","i price in lira sometimes. twenty four thousand. is four dollars. same number.","pinky no negotiate. pinky also a little negotiate."]
	return lines[host.random_index(lines.size())]+"\nhe smells of cologne and onion.\nhe is always saying it once."
func open(id: String) -> Dictionary:
	close()
	var reason := _reason(id)
	if not reason.is_empty(): return _fail(reason)
	var phone: Object = null
	if id == "phoneguy":
		phone = _dependency(_communications_ref,&"show_feed")
		if phone == null or not phone.has_method(&"post"): return _fail("communications_unavailable")
	var options := _options(id)
	var ids: Array[String] = []
	for option: Dictionary in options: ids.append(option.id)
	var opened: Dictionary = session.begin(id,ids)
	if not opened.ok: return opened
	if phone != null and phone.show_feed() != true:
		close(); return _fail("communications_unavailable")
	var tracked: Array = host.definition("src/data/catalogs.js","VENDOR_FLOATER_IDS",[])
	if id in tracked and not host.s.metVendors.has(id): host.s.metVendors.append(id); _save()
	var memory: Object = _dependency(_memory_ref,&"bother")
	if memory != null: memory.bother(id)
	host.s.mode = "dialogue"
	return {"ok":true,"token":opened.token,"actor":id,"title":TITLES[id],"text":_text(id),"options":options}
func close() -> void:
	session.close()
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason not in ["stale_session","replaced_state"] and host != null and host.s.mode == "dialogue": host.s.mode = "playing"
		return accepted
	if host.s.mode == "dialogue": host.s.mode = "playing"
	var id: String = accepted.target
	var reason := _reason(id)
	if not reason.is_empty(): return _fail(reason)
	var selected: Dictionary = {}
	for option: Dictionary in _options(id):
		if option.id == action: selected = option; break
	if selected.is_empty(): return _fail("action_unavailable")
	if not selected.enabled: return _fail(selected.reason)
	if action == "leave": return _done()
	var result: Dictionary
	match id:
		"pinky": result = _pinky(action)
		"phoneguy": result = _phone(action)
		"karaoke":
			if action == "request": _toast("he sings the song you want.\nyou did not request a song.\nyou wanted, in fact, to leave."); result = _done()
			else:
				var activities: Object = _dependency(_activities_ref,&"start_paid_karaoke")
				if activities == null: return _fail("activities_unavailable")
				result = activities.start_paid_karaoke()
				if result.get("ok",false): result.domain = "activities"
		"laundromat_lady": result = _laundry(action)
		_: result = _direct(id,action)
	if result.get("ok",false): host.emit_event("street_dialogue_action",{"actor":id,"action":action})
	return result

func _pinky(action: String) -> Dictionary:
	if action in ["buy_pass","use_pass"]:
		var travel: Object = _dependency(_travel_ref,&"buy_pinky_pass" if action == "buy_pass" else &"open")
		if travel == null: return _fail("travel_unavailable")
		if action == "buy_pass": return travel.buy_pinky_pass()
		var result: Dictionary = travel.open("bus")
		if result.get("ok",false): result.domain = "travel"
		return result
	if action == "no_like": _toast("he is delighted you said it back.\n'you no like? you go barb.'\nhe says it once more under his breath."); return _done()
	if action == "cut": _toast("'is house. is what house had.'\nhe gestures behind him.\nthere is no house."); return _done()
	var amount: int = 1 if action == "buy_one" else 5
	var cost: int = host.vendor_price(4 if amount == 1 else 18)
	host.p.cash -= cost; host.p.supplies += amount; host.p.dirtySupplies += amount
	if int(host.s.counters.get("pinkyFirstBuy",0)) == 0:
		host.s.counters.pinkyFirstBuy = 1; host.s.barbAside = true; host.unlock_achievement("due_dealer_system")
		host.emit_event("news",{"text":"DUE DEALER SYSTEM OBSERVED. THE NEIGHBORHOOD HAS OPTIONS NOW."})
		_feed("two packet guys. one block. choose your fighter.","@crackheadcent")
	_toast("- $%d\n+ 1 packet (house cut)\nhe winks. with both eyes." % cost if amount == 1 else "- $%d\n+ 5 packets (house cut)\nhe says 'amore.' he says it three times." % cost)
	host.apply_rep({"street":1 if amount == 1 else 2,"spiritual":-1 if amount == 1 else -2})
	_sound("coin"); _save()
	return _done()
func _phone(action: String) -> Dictionary:
	var phone: Object = _dependency(_communications_ref,&"post")
	if phone == null: return _fail("communications_unavailable")
	if action == "posting":
		var lines: Array[String] = ["tagged a man at the corner. he didn't notice.","live-posting a possum. 4 likes.","the conductor is trending in zone 2.","father o'malley followed me back.","pawn pete weighed a sock again. 11 min. 2 hearts."]
		if phone.post(lines[host.random_index(lines.size())],"@phone_guy") != true: return _fail("communications_unavailable")
		_toast("he flips the phone toward you. you see it.\nyou are in the post.\n(press P or tap FEED)")
	else:
		if phone.post("a man paid me $3 to make him famous. he is. for like 30 seconds.","@phone_guy") != true: return _fail("communications_unavailable")
		host.p.cash -= 3; _toast("- $3\nhe posts about you.\nthe post does numbers.\nthe numbers are 3.")
	return _done()
func _laundry(action: String) -> Dictionary:
	if action == "why":
		_toast("she does not answer. she folds.\nthe shirt has not been clean since 2009.\n(- 2 brain)"); host.p.brain = maxf(0,host.p.brain-2); return _done()
	var memory: Object = _dependency(_memory_ref,&"record")
	if memory == null: return _fail("memory_unavailable")
	if action == "laundry":
		host.p.cash -= 2; host.p.hp = minf(host.p.maxHp,host.p.hp+12)
		host.s.counters.laundryDone = int(host.s.counters.get("laundryDone",0))+1
		memory.record("laundromat","buy","laundry_service")
		_toast("- $2\n+ 12 hp\nyou wore wet clothes back outside.\nit smells like a different country in here.")
	else:
		if not inventory.append_item("detergent","a jug of detergent"): return _fail("inventory_rejected")
		host.p.cash -= 5; memory.record("laundromat","buy","detergent")
		_toast("- $5\n+ detergent\nyou are not going to use it. you know this. she knows this.")
	return _done()
func _direct(id: String,action: String) -> Dictionary:
	match id:
		"cubscout":
			if action == "popcorn": host.p.cash -= 8; host.p.cred += 4; _toast("- $8\n+ 4 cred\nyou ate a fistful in the parking lot."); _sound("coin")
			else: _toast("she is on her phone.\nshe has been on her phone for 11 minutes.")
		"jogger":
			if host.random_float() < 0.4: host.p.cash += 1; _toast("+ $1\nshe gave you a dollar she did not need.")
			else: _toast("she ran faster.\nthe ground absorbed your dignity.")
		"dogwalker": host.p.cred += 1; _toast("+ 1 cred\npaisley accepts you. tolerantly.")
		"busker":
			if action == "tip": host.p.cash -= 1; host.p.cred += 1; _toast("- $1\n+ 1 cred\nhe nods without losing the beat.")
			else: _toast("he plays the same song faster.\nthis is the new song now.")
		"horsecop":
			if action == "nod": host.p.cred += 2; _toast("you nod. the horse nods.\nthe cop nods. you are all nodding.\n+ 2 cred")
			elif action == "compliment":
				host.p.cred += 3; _toast("the horse looks pleased.\nthe cop is jealous.\n+ 3 cred")
				_feed("complimented the horse cop's horse. the horse was visibly pleased.","@local_eyewitness")
			elif host.random_float() < 0.4: host.p.cred += 4; _toast("the horse permits it.\nthe cop says nothing.\n+ 4 cred")
			else:
				host.p.hp -= 6; host.p.wanted = mini(3,int(host.p.wanted)+1)
				_toast("the horse rears.\nyou eat curb.\n- 6 hp · wanted +1")
		"vapelord":
			if action == "pod":
				host.p.cash -= 6; host.p.brain = minf(100,host.p.brain+10)
				_toast("- $6\n+ 10 brain\nthe flavor is \"spectrum\".\nyou cannot taste it. that is the flavor.")
			else: _toast("the vape lord says nothing.\nthe dragon stares.\nyou leave.")
		"pothole":
			if action == "argue": host.p.brain = maxf(0,host.p.brain-4); _toast("- 4 brain\nthe pothole has more facts than you do.\nthe pothole is also correct.")
			elif host.p.cash >= 1: host.p.cash -= 1; host.p.cred += 1; _toast("- $1\n+ 1 cred\nthe pothole accepts.\nthe pothole says 'thank you' in your mother's voice.")
			else: _toast("you have nothing to throw.\nthe pothole understands. the pothole is patient.")
		"mayorscousin":
			if action == "mayor": _toast("the mayor is, in fact, his cousin.\nthe mayor does not return his calls.\nthis information is true and useless.")
			elif action == "bribe": host.p.cash -= 5; host.p.cred += 8; _toast("- $5\n+ 8 cred\nhe whispers 'i'll remember this.'\nhe will not.")
			elif host.random_float() < 0.3: host.p.wanted = maxi(0,int(host.p.wanted)-1); _toast("a phone call is made.\nthe heat dies down.\n- 1 wanted")
			else: _toast("he makes a phone call.\nthe phone is a piece of bread.")
		"meter_maid":
			if action == "meter": host.p.cash -= 2; host.p.wanted = maxi(0,int(host.p.wanted)-1); _toast("- $2\n- 1 wanted\nthe meter accepts. begrudgingly.")
			else: host.p.wanted = mini(3,int(host.p.wanted)+1); _toast("she looks you up and down.\nshe writes another ticket.\nthe ticket is for you. it says 'INSUFFICIENT.'")
		"food_truck":
			if action == "horchata": host.p.cash -= 8; host.p.brain = minf(100,host.p.brain+30); _toast("- $8 · + 30 brain\nit tastes like a memory you don't have.")
			elif action == "burrito":
				host.p.cash -= 15; host.p.rocks += 1; host.p.wanted = mini(3,int(host.p.wanted)+1)
				_toast("- $15 · + 1 rock · wanted +1\nthe burrito had a rock in it.\nthe rock is the burrito.")
				_feed("food truck guy is selling rocks. probably. this is the news.","@local_eyewitness")
			else:
				host.p.cash -= 4; host.p.hp = minf(host.p.maxHp,host.p.hp+20)
				host.s.counters.tacosEaten = int(host.s.counters.get("tacosEaten",0))+1
				var roll: float = host.random_float()
				if roll < 0.15: host.p.shakes = maxf(0,host.p.shakes-20); _toast("- $4 · + 20 hp · - 20 shakes\nthe taco had something in it.\nyou should not ask.")
				elif roll < 0.25: host.p.hp -= 30; _toast("- $4 · + 20 hp · - 30 hp\nthe taco had something in it.\nyou ARE asking now."); _sound("hurt")
				else: _toast("- $4 · + 20 hp\nthe taco was a taco. you are stunned.")
		"priests_son":
			if action == "priest": host.p.brain = maxf(0,host.p.brain-1); _toast("'he's not my dad.'\n(the eyes are the same.)\n(- 1 brain)")
			else:
				host.p.cash -= 10
				if host.random_float() < 0.5: host.p.rocks += 1; _toast("- $10 · + 1 rock\nthe priest's son is a businessman.")
				else: _toast("- $10\nit was. it was just a tic-tac.\nthe priest's son walks away whistling.")
	return _done()
