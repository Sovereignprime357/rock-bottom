class_name RockBottomResidentDialogue
extends RefCounted
## Source resident actions. Menus submit capabilities; GameState remains the only authority.
const Session = preload("res://scripts/action_session.gd")
const IDS := ["lurch","sherri","paulie","larry","mom","priest","omalley_fallen","math","train_hopper","philosopher"]
const TITLES := {"lurch":"LURCH","sherri":"SPIDER-BITE SHERRI","paulie":"PAULIE THE FACE","larry":"LOUD LARRY","mom":"WHOLE FOODS MOM","priest":"FATHER O'MALLEY","math":"THE MATHEMATICIAN","train_hopper":"THE TRAIN HOPPER","philosopher":"PARK BENCH PHILOSOPHER"}
var _host_ref: WeakRef
var _memory_ref: WeakRef
var _combat_ref: WeakRef
var _boss_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted

func _init(owner: RefCounted, spatial_adapter: Object, memory: RefCounted = null, combat: RefCounted = null, bosses: RefCounted = null) -> void:
	_host_ref = weakref(owner)
	_memory_ref = weakref(memory) if memory != null else null
	_combat_ref = weakref(combat) if combat != null else null
	_boss_ref = weakref(bosses) if bosses != null else null
	session = Session.new(owner,spatial_adapter)

func supports(id: String) -> bool: return id in IDS
func _kind(id: String) -> String: return "priest" if id == "omalley_fallen" else id
func _actor(id: String) -> Dictionary:
	if host != null:
		for body: Dictionary in host.npcs:
			if body.get("id") == id: return body
	return {}
func _dependency(reference: WeakRef, method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func _night() -> bool: return float(host.s.dayTime) < 0.25 or float(host.s.dayTime) > 0.75
func _today(key: String) -> bool: return int(host.s.counters.get(key,0)) == int(host.s.day)
func _fallen() -> bool: return host.s.flags.get("omalleyFallen",false) and not host.s.flags.get("omalleyFallenDead",false)
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
func _option(id: String, label: String, enabled: bool = true, reason: String = "insufficient_cash") -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else reason}
func _toast(line: String, duration: int = 2200) -> void: host.emit_event("toast",{"text":line,"duration_ms":duration})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _save() -> void: host.emit_event("save_requested")
func _quest(id: String, title: String) -> void:
	host.s.quests[id].done = true
	host.emit_event("quest_completed",{"id":id})
	_toast("· QUEST COMPLETE ·\n"+title); _sound("rankUp")
func _done() -> Dictionary: return {"ok":true,"closed":true}
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}

func _options(id: String) -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	var cash: int = host.p.cash
	match _kind(id):
		"lurch":
			opts.append(_option("give","give a dollar. (he has forgotten you specifically.)" if _today("lurchDollarDay") else ("give a dollar. (+2 cred)" if cash >= 1 else "you don't have a dollar."),_today("lurchDollarDay") or cash >= 1))
			opts.append(_option("lie","lie. say you have a dollar."))
			opts.append(_option("sleeps","ask where he sleeps."))
			opts.append(_option("fight","fight."))
		"sherri":
			opts.append(_option("spider","pretend to see the spider. (she has shown you today.)" if _today("sherriSpiderDay") else "pretend to see the spider."))
			opts.append(_option("saw","ask what she saw."))
			opts.append(_option("fight","tell her there is no spider."))
		"paulie":
			opts.append(_option("compliment","compliment the face. (the face has heard.)" if _today("paulieFaceDay") else "compliment the face. (+1 cred)"))
			opts.append(_option("hears","ask what the face hears."))
			opts.append(_option("fight","fight."))
		"larry":
			opts.append(_option("shout","match volume. (+1 cred)"))
			opts.append(_option("fight","fight."))
		"mom":
			if not _night():
				if not _today("kombuchaAskDay"):
					opts.append(_option("accept","accept $10 and pity. (+$10)")); opts.append(_option("ask_twenty","ask for $20."))
				else: opts.append(_option("ask_again","ask her for money. (she remembers.)"))
				opts.append(_option("compliment","compliment her kombucha again." if _today("kombuchaComplimentDay") else "compliment her kombucha. (+5 cred)"))
				if host.p.faction.spiritual >= 10 and not host.s.flags.get("momHideoutOwned",false):
					opts.append(_option("couch","ask mom if you can stay over. ($30/night.)" if cash >= 30 else "ask mom if you can stay over. ($30 — short.)",cash >= 30))
		"priest":
			if not _fallen():
				opts.append(_option("tic_tac","accept the blessed tic-tac. (+5 brain)"))
				opts.append(_option("donate","donate $5. (the lord heard already.)" if _today("priestDonateDay") else ("donate $5. (+3 cred)" if cash >= 5 else "donate $5."),_today("priestDonateDay") or cash >= 5))
				opts.append(_option("steal","steal the collection plate."))
		"math":
			opts.append(_option("another","ask for another number.")); opts.append(_option("calculates","ask what he calculates."))
		"train_hopper":
			if not _night():
				opts.append(_option("trains","ask about the trains.")); opts.append(_option("another","ask where he's been."))
		"philosopher":
			opts.append(_option("think","think about it. (you already did today.)" if _today("philosopherRepDay") else "think about it. (+1 spiritual)"))
			opts.append(_option("why","ask why she's here."))
	opts.append(_option("leave","leave."))
	return opts

func open(id: String) -> Dictionary:
	close()
	var reason := _reason(id)
	if not reason.is_empty(): return _fail(reason)
	var options: Array[Dictionary] = _options(id)
	var ids: Array[String] = []
	for option: Dictionary in options: ids.append(option.id)
	var opened: Dictionary = session.begin(id,ids)
	if not opened.ok: return opened
	var tracked: Array = host.definition("src/data/catalogs.js","VENDOR_FLOATER_IDS",[])
	if id in tracked and not host.s.metVendors.has(id): host.s.metVendors.append(id); _save()
	var memory: Object = _dependency(_memory_ref,&"bother")
	if memory != null: memory.bother(id)
	var kind := _kind(id)
	if kind == "train_hopper" and _night():
		close(); _toast("the freight car is dark.\nyou hear breathing inside.\nyou do not wake him.",2800); return _done()
	if kind == "priest": host.s.counters.priestVisits = int(host.s.counters.get("priestVisits",0))+1
	if kind == "math": host.s.counters.mathInteractions = int(host.s.counters.get("mathInteractions",0))+1
	if kind == "train_hopper" and not host.s.flags.get("trainHopperTalkedTo",false):
		host.s.flags.trainHopperTalkedTo = true; host.unlock_achievement("train_hopped")
	var text: String = _text(kind)
	host.s.mode = "dialogue"
	return {"ok":true,"token":opened.token,"actor":id,"title":TITLES[kind],"text":text,"options":options}

func close() -> void:
	session.close()
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"

func select(token: Variant, action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason not in ["stale_session","replaced_state"] and host != null and host.s.mode == "dialogue": host.s.mode = "playing"
		return accepted
	var id: String = accepted.target
	var reason := _reason(id)
	if host != null and host.s.mode == "dialogue": host.s.mode = "playing"
	if not reason.is_empty(): return _fail(reason)
	var selected: Dictionary = {}
	for option: Dictionary in _options(id):
		if option.id == action: selected = option; break
	if selected.is_empty(): return _fail("action_unavailable")
	if not selected.enabled: return _fail(selected.reason)
	if action == "leave": return _done()
	var result: Dictionary
	match _kind(id):
		"lurch","sherri","paulie","larry": result = _street(id,action)
		"mom": result = _mom(action)
		"priest": result = _priest(action)
		"math":
			if action == "another": return open(id)
			_toast("'expectation.'\nhe taps the clipboard.\n'i do not predict. i only count.'"); result = _done()
		"train_hopper":
			if action == "another": return open(id)
			host.p.brain = maxf(0.0,float(host.p.brain)-2.0)
			_toast("'they don't stop here anymore.\nthey come through.\nthey come through.'\n(- 2 brain)",4200); result = _done()
		"philosopher": result = _philosopher(action)
		_: return _fail("unknown_resident")
	if result.ok: host.emit_event("resident_action",{"actor":id,"action":action})
	return result

func _text(kind: String) -> String:
	match kind:
		"lurch": return "you got a dollar.\nhe smells like ham."
		"sherri": return "you seen the spider.\nshe is rolling her sleeve back down."
		"paulie": return "the face.\nit is. it really is. just the face."
		"larry": return "WHAT.\nWHAT.\nWHAT WHAT WHAT."
		"mom": return "she is not here at night.\nshe is at the wine bar with kelly." if _night() else "oh. oh sweetie.\nshe is wearing vibram five-fingers.\nshe is holding kombucha."
		"priest": return "the collar is on the floor.\nthe smile is wrong.\nthe medicine is no longer offered." if _fallen() else "medicine. open your mouth.\nhe is holding a tic-tac."
		"math": return _math_text()
		"train_hopper":
			var lines: Array = host.definition("src/dialogue/vendors_places.js","HOPPER_LINES",[])
			return "he is wiry. a beard the color of old steel.\nhe does not stand up.\n\n"+str(lines[host.random_index(lines.size())])
		"philosopher":
			var questions: Array = host.definition("src/dialogue/vendors_places.js","PHILOSOPHER_QUESTIONS",[])
			var index: int = posmod(int(host.s.day)-1,questions.size())
			return "an old woman feeding pigeons.\nbrown coat. gray hair.\nshe regards you with the patience of someone who has run out of patience.\n\n'"+str(questions[index])+"'"
	return ""

func _math_text() -> String:
	var count: int = host.s.counters.mathInteractions
	var factor: float = clampf((float(host.p.brain)-30.0)/70.0,-0.4,0.6)
	if host.p.rockedT > 0: factor -= 0.25
	var double_chance := clampf(0.08+factor*0.15,0.0,0.7)
	var burn_chance := clampf(0.10-factor*0.08,0.02,0.5)
	var expectation: float = 1.0-burn_chance+double_chance
	var cents: String = ("%.2f" % maxf(0.0,expectation*6.0-5.0)).substr(2)
	var lines: Array[String] = [
		"%d percent of two. you a coin flip with a busted edge." % int(floor(expectation*100.0+0.5)),
		"brain %d. " % int(floor(float(host.p.brain)+0.5)) + ("rocked up. shaky scientist. minus point two five. don't." if host.p.rockedT > 0 else "shaky mode equals minus point one eight. don't."),
		"expectation: a buck "+cents+". you smoke it you lose two dollars and a year.",
		"the math says barb. the math also says you sell. the math is a coward.",
		"tony charges ten. you cook for five. the gap is moral."]
	if host.p.dirtySupplies > 0: lines.append("%d dirty in the bag. soap rate twenty five. pinky knows what he did." % int(host.p.dirtySupplies))
	var lead: String = lines[host.random_index(lines.size())]
	var tips: Array[String] = [
		"the cook brain factor: brain minus thirty over seventy. minus point two five if you smoked first. they don't print that anywhere.",
		"stripe's coin lands soap two of every five tosses. forty percent. you knew. you kept buying.",
		"tony's patience is three. you short him three times. the corner becomes arena. simple math.",
		"twenty two coins are on the ground. you have stepped on most of them already. hold F. the math is green.",
		"the priest's son is half tic-tac, half rock. exactly half. fifty fifty. flip your coin."]
	var tip: String = ""
	var index: int = int(floor(float(count)/3.0))-1
	if count%3 == 0 and index >= 0 and index < tips.size(): tip = tips[index]; host.apply_rep({"scrap":1})
	return "he looks up from a clipboard.\n"+lead+("\n\n· the numbers know what you did ·\n"+tip if not tip.is_empty() else "")

func _street(id: String, action: String) -> Dictionary:
	if action == "fight":
		var combat: Object = _dependency(_combat_ref,&"aggro")
		if combat == null or combat.aggro(id) != true: return _fail("combat_unavailable")
		if id == "lurch": _toast("lurch swings. so do you. it begins.")
		elif id == "sherri": _toast("the spider is back.\nshe is hostile now.")
		return _done()
	if action in ["sleeps","saw","hears"]: return _reveal(action)
	match id:
		"lurch":
			if action == "lie": _toast("lurch nods. waits. lurch is still waiting.\n(the lie did not work. he is just waiting.)")
			elif _today("lurchDollarDay"): _toast("lurch is full. of dollars.\nhe is staring at the wall.\ncome back tomorrow.",3000)
			else:
				host.p.cash -= 1; host.p.cred += 2; host.s.counters.lurchDollarDay = host.s.day
				_toast("- $1\n+ 2 cred\nlurch immediately forgets.\ncome back tomorrow."); _save()
		"sherri":
			if _today("sherriSpiderDay"): _toast("sherri's sleeve is already down.\nthe spider is sleeping.\ncome back tomorrow.",3000)
			else:
				host.p.cred += 1; host.s.counters.sherriSpiderDay = host.s.day
				_toast("sherri respects you. (+1 cred)\ncome back tomorrow."); _save()
		"paulie":
			if _today("paulieFaceDay"): _toast("paulie nods. the face is satisfied.\nthe face has been complimented today.\ncome back tomorrow.",3000)
			else:
				host.p.cred += 1; host.s.counters.pauliCompliments = int(host.s.counters.get("pauliCompliments",0))+1
				host.s.counters.paulieFaceDay = host.s.day
				if host.s.counters.pauliCompliments >= 5: host.unlock_achievement("compliment_the_face")
				_toast("paulie does not smile but the face changes.\n+ 1 cred\ncome back tomorrow."); _save()
		"larry": host.p.cred += 1; _toast("YOU YELL BACK.\nlarry respects this.\n+ 1 cred")
	return _done()

func _reveal(action: String) -> Dictionary:
	var memory: Object = _dependency(_memory_ref,&"tell")
	if memory == null or not memory.has_method(&"discovered"): return _fail("memory_unavailable")
	match action:
		"sleeps": memory.tell("underpass","under the bridge. not lately.\nthere is a dog now. the dog has a lanyard.\narrangements exist.","the bridge. the dog.\nlurch says it exactly the same as before.","lurch says the bridge has a dog now. arrangements exist.")
		"hears": memory.tell("choir_office","the choir office keeps hours.\nb flat to b flat.\nthe face does not attend.","the face says it again. identical.\nthe hours have not moved.","paulie says the choir office keeps hours. b flat to b flat.")
		"saw":
			if not memory.discovered("park"): memory.tell("park","the bench by the fountain.\nafter dark the philosopher stops counting.\nhe is not asleep. he is polite.","the bench. after dark.\nsherri has said this already.","sherri saw something at the park bench. after dark.")
			elif not memory.discovered("laundromat"): memory.tell("laundromat","the laundromat. mid-cycle.\nthe dryer provides.\nsherri does not say what.","the dryer. mid-cycle.\nsherri has said this already.","sherri says the dryer provides. mid-cycle. noted.")
			else: _toast("sherri rolls her sleeve up an inch.\nputs it back down.\nshe has told you what she saw.",3000)
	return _done()

func _mom(action: String) -> Dictionary:
	match action:
		"accept","ask_twenty":
			host.s.counters.kombuchaAskDay = host.s.day
			if action == "accept":
				host.p.cash += 10; _toast("+ $10\nshe will tell ben about you tonight.\nben will not care.\ncome back tomorrow."); _sound("coin")
			elif host.random_float() < 0.4:
				host.p.cash += 20; _toast("+ $20\nshe pauses. she sighs. she gives.\nben will be furious.\ncome back tomorrow."); _sound("coin")
			else:
				host.p.brain = maxf(0.0,float(host.p.brain)-2.0)
				_toast("she explains capitalism for 4 minutes.\nyou leave with no money and -2 brain.\ncome back tomorrow.")
			host.apply_rep({"spiritual":-1}); _save()
		"ask_again": _toast("you've been by. she remembers.\nshe remembers because she has nothing else to do.\ncome back tomorrow.",3600)
		"compliment":
			if _today("kombuchaComplimentDay"): _toast("she has heard about her kombucha today.\nshe is tired of her kombucha.\nshe is tired of you.",3600)
			else:
				host.p.cred += 5; host.s.counters.kombuchaComplimentDay = host.s.day
				_toast("she lights up.\nshe tells you it's lavender.\nyou agree it is lavender.\n+ 5 cred\ncome back tomorrow.")
				host.apply_rep({"spiritual":1}); _save()
		"couch":
			host.p.cash -= 30; host.s.flags.momHideoutOwned = true; host.s.flags.momRentDay = host.s.day
			_toast("- $30\n'oh sweetie.\nthe couch is yours.\nben works late.'\n(the spare key is on the hook.)",4200)
			host.emit_event("feed",{"text":"got a couch tonight. ben works late.","author":"@crackheadcent"})
			host.apply_rep({"spiritual":2}); _save()
	return _done()

func _priest(action: String) -> Dictionary:
	match action:
		"tic_tac":
			host.p.brain = minf(100.0,float(host.p.brain)+5.0)
			_toast("the tic tac is gone.\nthe shakes do not care.")
			if not host.s.quests.priest_mercy.done: _quest("priest_mercy","THE PRIEST'S MERCY")
			_save()
		"donate":
			if _today("priestDonateDay"): _toast("father o'malley nods.\n'the lord has counted today.\ncome back tomorrow.'",3000)
			else:
				host.p.cash -= 5; host.p.cred += 3
				host.s.counters.churchDonations = int(host.s.counters.get("churchDonations",0))+5
				host.s.counters.priestDonateDay = host.s.day
				if host.s.counters.churchDonations >= 100: host.unlock_achievement("ecclesiastes")
				_toast("- $5\n+ 3 cred\nthe lord notices. then forgets.\ncome back tomorrow.")
				host.apply_rep({"spiritual":2}); _save()
		"steal":
			var transform: bool = int(host.s.counters.get("priestVisits",0)) >= 4 and not host.s.flags.get("omalleyFallen",false) and host.p.faction.spiritual < 10
			if transform:
				var bosses: Object = _dependency(_boss_ref,&"transform_fallen_priest")
				if bosses == null or bosses.transform_fallen_priest() != true: return _fail("boss_unavailable")
			host.s.counters.plateStealAttempts = int(host.s.counters.get("plateStealAttempts",0))+1
			if transform: host.apply_rep({"street":1,"spiritual":-3}); return _done()
			if host.random_float() < 0.55:
				host.p.cash += 22; host.s.counters.plateStolen = int(host.s.counters.get("plateStolen",0))+1
				if host.s.counters.plateStolen >= 1 and int(host.s.counters.get("stripeBetrayed",0)) >= 1: host.unlock_achievement("judas")
				_toast("+ $22\n(the lord is busy.)"); _sound("pickup")
			else:
				# Source menu consequence deliberately bypasses hurt/iframes/immediate death.
				host.p.hp -= 12; host.p.wanted = mini(3,int(host.p.wanted)+1)
				_toast("father o'malley smites you.\n- 12 hp · wanted +1"); _sound("hurt")
			host.apply_rep({"street":1,"spiritual":-3}); _save()
	return _done()

func _philosopher(action: String) -> Dictionary:
	if action == "why": _toast("'i live in the building.\nthe bench is closer.\nthe pigeons remember faces.'",3600)
	elif _today("philosopherRepDay"): _toast("she has asked already today.\nshe is patient.\nthe pigeons are not.",2800)
	else:
		host.s.counters.philosopherRepDay = host.s.day; host.apply_rep({"spiritual":1})
		_toast("you stand there.\nshe nods.\nthe pigeon nods.\n+ 1 spiritual",3200)
	return _done()
