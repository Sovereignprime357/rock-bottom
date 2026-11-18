class_name RockBottomCompanions
extends RefCounted
## Four authored conversations and pet lifecycle; Director/Combat retain movement and HP.
const Session = preload("res://scripts/action_session.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Lockpick = preload("res://scripts/lockpick_system.gd")
const IDS := ["possum","pet_possum","scrap_dog","freed_dog_follower"]
const RECOVERY_PX: float = 100.0
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _communications_ref: WeakRef
var _director_ref: WeakRef
var _dumpster_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var session: RefCounted
var inventory: RefCounted
var puzzle: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _menu_player: Dictionary = {}
var _menu_state: Dictionary = {}
var _actor_id: String = ""
var _branch: String = ""
var _page: String = ""
var _lock_context: String = ""
var _wall_ms: float = 0.0
var _pet_due: float = -1.0
var _pending_pet: Dictionary = {}
var _pending_dog: Dictionary = {}
var _pending_reveal: Dictionary = {}

func _init(owner: RefCounted,spatial: Object,communications: RefCounted,shared_lockpick: RefCounted = null,director: RefCounted = null) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null
	_communications_ref = weakref(communications) if communications != null else null
	_director_ref = weakref(director) if director != null else null
	puzzle = shared_lockpick if shared_lockpick != null else Lockpick.new(owner)
	_lock_context = "companion:%d" % get_instance_id()
	session = Session.new(owner,self,&"_session_available"); inventory = Inventory.new(owner)
	_sync_epoch()
	if director != null: director.set_companion_owner(self)
func bind_director(director: RefCounted) -> void:
	_director_ref = weakref(director) if director != null else null
	if director != null: director.set_companion_owner(self)
func _object(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func _sync_epoch() -> bool:
	if host == null: return false
	if not is_same(_player_epoch,host.p) or not is_same(_state_epoch,host.s):
		close(); _player_epoch = host.p; _state_epoch = host.s
		_pet_due = -1.0; _pending_pet.clear(); _pending_dog.clear(); _pending_reveal.clear()
		var original_dog: Dictionary = _actor("scrap_dog")
		if host.s.quests.get("scrap_dog",{}).get("state") == "freed" and original_dog.get("dead",false): original_dog.departed = true
		host.p.hasPossum = false; host.s.freedDogT = 0.0; host.s.freedDogFollowT = 0.0; host.s.freedDogFirstReturn = false
	return true
func ready() -> bool:
	if not _sync_epoch(): return false
	var lines: Variant = host.definition("src/dialogue/neighborhood_a.js","LOCAL_POSSUM_PROPHECIES",[])
	var comm: Object = _object(_communications_ref,&"ready")
	return lines is Array and lines.size() == 16 and comm != null and comm.ready() == true and comm.has_method(&"post") and comm.has_method(&"broadcast")
func supports(id: String) -> bool: return id in IDS
func _actor(id: String,live: bool = false) -> Dictionary:
	if host != null:
		for body: Dictionary in host.npcs:
			if body.get("id") == id and (not live or not body.get("dead",false)): return body
	return {}
func _center(body: Dictionary) -> Vector2: return Vector2(float(body.x)+float(body.w)*0.5,float(body.y)+float(body.h)*0.5)
func _reason(id: String) -> String:
	if not ready(): return "missing_dependency"
	if not supports(id): return "unknown_companion"
	if host.s.mode not in ["playing","dialogue"]: return "wrong_mode"
	if host.s.get("bossKind","") == "kingdom": return "active_boss"
	var body: Dictionary = _actor(id,true)
	if body.is_empty(): return "missing_companion"
	if host.player_center().distance_squared_to(_center(body)) >= 3600.0: return "out_of_reach"
	var spatial: Object = _object(_spatial_ref,&"can_reach_target")
	if spatial == null: return "missing_spatial_adapter"
	if spatial.call(&"can_reach_target",id) != true: return "out_of_reach"
	return ""
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})
func _save() -> void: host.emit_event("save_requested")
func _post(text: String) -> void: (_communications_ref.get_ref() as Object).post(text,"@crackheadcent")
func _option(id: String,label: String,enabled: bool = true) -> Dictionary:
	return {"id":id,"label":label,"enabled":enabled,"reason":"" if enabled else "unavailable"}
func is_active() -> bool:
	return host != null and not _page.is_empty() and is_same(_menu_player,host.p) and is_same(_menu_state,host.s)
func _session_available(id: String) -> bool:
	if not is_active() or host.s.mode != "dialogue" or id != _actor_id: return false
	if _page == "lock": return puzzle.active(_lock_context)
	if _actor_id == "dumpster_possum": return ready()
	if _actor_id == "scrap_dog" and str(host.s.quests.scrap_dog.state) != _branch: return false
	return _reason(id).is_empty()
func open(id: String) -> Dictionary:
	var reason: String = _reason(id)
	if not reason.is_empty(): return _fail(reason)
	close(); _menu_player = host.p; _menu_state = host.s; _actor_id = id; _page = "main"
	if id == "scrap_dog":
		if not host.s.quests.get("scrap_dog") is Dictionary: close(); return _fail("missing_quest")
		_branch = str(host.s.quests.scrap_dog.state)
		if _branch == "idle": host.s.quests.scrap_dog.available = true
	return _menu()
func set_dumpster_authority(owner: Object) -> void: _dumpster_ref = weakref(owner) if owner != null else null
func open_from_dumpster(ticket: Variant) -> Dictionary:
	if not ready(): return _fail("missing_dependency")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	var authority: Object = _object(_dumpster_ref,&"consume_possum_handoff")
	if authority == null or authority.call(&"consume_possum_handoff",ticket) != true: return _fail("missing_dumpster_capability")
	close(); _menu_player = host.p; _menu_state = host.s; _actor_id = "dumpster_possum"; _page = "main"
	return _menu()
func _options() -> Array[Dictionary]:
	if _page == "lock":
		var pins: Array[Dictionary] = []
		for pin: int in range(1,5): pins.append(_option("pin:%d" % pin,"%d. set pin %d" % [pin,pin]))
		pins.append(_option("give_up","give up.")); return pins
	match _actor_id:
		"possum","dumpster_possum": return [_option("prophecy","request a prophecy."),_option("pet","pet the possum."),_option("leave","leave.")]
		"pet_possum": return [_option("release","release the possum back to the wild."),_option("leave","leave.")]
		"freed_dog_follower": return [_option("pet","pet him."),_option("leave","leave.")]
		"scrap_dog":
			if _branch == "fed": return [_option("pet","pet him."),_option("leave","leave him.")]
			if _branch == "freed": return [_option("leave","leave.")]
			var has_food: bool = inventory.count_records("food") > 0
			return [_option("feed","feed him. (-1 food, +1 cred)" if has_food or _branch == "left" else "feed him. (you have no food.)",has_food),_option("free","free him. (lockpick.)"),_option("leave","leave." if _branch == "left" else "leave him.")]
	return []
func _menu() -> Dictionary:
	var title: String = "THE DOG"
	var text: String = ""
	if _page == "lock":
		var view: Dictionary = puzzle.snapshot(_lock_context)
		if view.is_empty(): close(); return _fail("stale_puzzle")
		title = view.title; text = view.text
	else:
		match _actor_id:
			"possum","dumpster_possum":
				title = "THE POSSUM"; text = "a possum wearing a tiny construction helmet looks up.\nhe is calculating something."
			"pet_possum":
				title = "YOUR POSSUM"; text = "he stares.\nhe has been with you for some time now.\nhe has things to say. he will not."
			"freed_dog_follower": text = "the dog.\nbrown. less matted.\nhe is here. for now."
			"scrap_dog":
				match _branch:
					"fed": text = "the dog. fed. matted but slightly less so.\nhe blinks. once. that's the whole interaction."
					"freed": title = "THE DOG (gone)"; text = "the post is here.\nthe chain is on the ground.\nthe dog is not here."
					"left": text = "the dog. still chained.\nhe blinks at you.\nhe has been waiting."
					_: text = "the dog. brown. matted.\nchained to a post that looks bored.\nhe blinks at you twice."
	var options: Array[Dictionary] = _options()
	var actions: Array[String] = []
	for option: Dictionary in options: actions.append(option.id)
	host.s.mode = "dialogue"
	var opened: Dictionary = session.begin(_actor_id,actions)
	if not opened.ok: close(); return opened
	return {"ok":true,"domain":"companion","token":opened.token,"actor":_actor_id,"title":title,"text":text,"options":options}
func select(token: Variant,action: String) -> Dictionary:
	var accepted: Dictionary = session.consume(token,action)
	if not accepted.ok:
		if accepted.reason != "stale_session": close()
		return accepted
	var enabled: bool = false
	for option: Dictionary in _options():
		if option.id == action: enabled = option.enabled; break
	if not enabled: close(); return _fail("action_unavailable")
	host.s.mode = "playing"
	if _page == "lock":
		if action == "give_up": close(); _toast("the lock holds.\nthe dog watches.\nhe is patient. you are not.",2400); return {"ok":true,"closed":true}
		var picked: Dictionary = puzzle.choose(_lock_context,int(action.get_slice(":",1)))
		if not picked.ok: close(); return picked
		if picked.complete: close(); _free_dog(); return {"ok":true,"closed":true}
		return _menu()
	var id: String = _actor_id; var branch: String = _branch
	if action == "free":
		puzzle.begin(_lock_context); _page = "lock"; return _menu()
	close()
	match id:
		"possum","dumpster_possum":
			if action == "prophecy": _prophecy()
			elif action == "pet": _toast("you do not pet the possum.\nthe possum decides this."); host.unlock_achievement("the_route")
		"pet_possum":
			if action == "release":
				_depart(_actor(id)); host.p.hasPossum = false
				_toast("you set the possum down.\nhe walks the other way without looking back.\nyou understand.")
		"freed_dog_follower":
			if action == "pet": host.p.cred += 1; _toast("he accepts.\nhe leans into it.\nthe wandering resumes.",2400)
		"scrap_dog":
			if action == "pet": host.p.cred += 1; _toast("the dog accepts. tolerantly.\nthe chain rattles.",1800); _save()
			elif action == "feed":
				inventory.remove_first_record("food"); host.p.cred += 1
				host.s.quests.scrap_dog.state = "fed"; host.s.quests.scrap_dog.done = true
				_toast("he ate it without looking up.\nhe looks at you once.\nthen back to the food.",3200)
				_post("fed the scrap-yard dog."); host.apply_rep({"scrap":2}); _save()
			elif action == "leave" and branch not in ["fed","freed","left"]:
				host.s.quests.scrap_dog.state = "left"; host.s.quests.scrap_dog.done = true; host.s.quests.scrap_dog.available = false
				_toast("the dog blinks again. you walk away.\nhe is still there.\nhe is still there.",2600); _save()
	return {"ok":true,"closed":true}
func close() -> void:
	if is_active() and (_page != "lock" or puzzle.active(_lock_context)) and host.s.mode == "dialogue": host.s.mode = "playing"
	if session != null: session.close()
	if puzzle != null: puzzle.cancel(_lock_context)
	_actor_id = ""; _branch = ""; _page = ""; _menu_player = {}; _menu_state = {}
func _prophecy() -> void:
	_toast("the possum is thinking. give him a second.",1500)
	var lines: Array = host.definition("src/dialogue/neighborhood_a.js","LOCAL_POSSUM_PROPHECIES",[])
	var line: String = str(lines[host.random_index(lines.size())]); _toast(line,5500)
	host.s.counters.possumProphecies += 1
	if host.s.counters.possumProphecies >= 10: host.unlock_achievement("i_have_seen_horrors")
	if host.s.counters.possumProphecies >= 5 and not host.p.get("hasPossum",false) and _pet_due < 0.0 and _pending_pet.is_empty(): _pet_due = _wall_ms+2200.0
	match host.random_index(4):
		0: host.p.cash += 2; _toast(line+"\n+ $2",5500)
		1: host.p.brain = maxf(0,host.p.brain-3)
		2: host.p.cred += 1
func _depart(body: Dictionary) -> void:
	if body.is_empty(): return
	body.dead = true; body.departed = true
	if body.id == "pet_possum": _pending_reveal.clear()
	host.emit_event("actor_departed",{"actor_id":body.id,"reason":"companion"})
func _free_dog() -> void:
	var dog: Dictionary = _actor("scrap_dog")
	if not dog.is_empty(): _depart(dog); dog.chained = false
	host.s.quests.scrap_dog.state = "freed"; host.s.quests.scrap_dog.done = true; host.s.quests.scrap_dog.available = false
	host.s.freedDogT = 60000.0+host.random_float()*120000.0
	_sound("glassBreak"); host.unlock_achievement("liberator")
	_toast("CLICK. the lock falls.\nthe dog stands up.\nhe walks past you. he does not look at you.\nhe is gone.",4400)
	_post("freed the dog. the dog did not stay."); host.apply_rep({"scrap":3,"spiritual":-1}); _save()
func _valid_step(dt: float) -> bool: return is_finite(dt) and dt > 0.0 and dt <= 50.0
func _valid_point(point: Variant,origin: Vector2,size: Vector2 = Vector2.ZERO) -> bool:
	if not point is Vector2 or not point.is_finite() or point.distance_to(origin) > RECOVERY_PX+0.0001: return false
	var bounds: Dictionary = host.content.world.bounds
	return point.x >= 0.0 and point.y >= 0.0 and point.x+size.x <= float(bounds.w) and point.y+size.y <= float(bounds.h)
func _place_actor(body: Dictionary) -> bool:
	var spatial: Object = _object(_spatial_ref,&"clear_placement")
	if spatial == null: return false
	var origin := Vector2(float(body.x),float(body.y))
	var point: Variant = spatial.call(&"clear_placement",body.duplicate(true))
	if not _valid_point(point,origin,Vector2(float(body.w),float(body.h))): return false
	body.x = point.x; body.y = point.y
	return true
func _insert_actor(body: Dictionary,replace_dead: bool) -> void:
	var replaced: bool = false
	if replace_dead:
		for index: int in range(host.npcs.size()-1,-1,-1):
			if host.npcs[index].id == body.id and host.npcs[index].get("dead",false): host.npcs.remove_at(index); replaced = true
	var director: Object = _object(_director_ref,&"reset_actor")
	if director != null: director.reset_actor(str(body.id))
	host.npcs.append(body)
	host.emit_event("actor_spawned",{"actor_id":body.id,"replaced":replaced})
func spawn_pet_possum() -> Dictionary:
	if not ready(): return _fail("missing_dependency")
	if not _actor("pet_possum").is_empty(): _pending_pet.clear(); return {"ok":true,"already_present":true}
	if _pending_pet.is_empty():
		_pending_pet = {"id":"pet_possum","name":"YOUR POSSUM","sprite":"possum","x":host.p.x-30.0,"y":host.p.y+12.0,"w":28,"h":24,"color":"#604030","hp":30,"maxHp":30,"speed":1.6,"hostile":false,"isPet":true,"frame":0}
	if not _place_actor(_pending_pet): return {"ok":true,"pending":true}
	var body: Dictionary = _pending_pet; _pending_pet = {}; _insert_actor(body,false)
	host.p.hasPossum = true
	_toast("the possum follows you now.\nhe is on his route.\nyou are on his route.",3500)
	(_communications_ref.get_ref() as Object).broadcast("LOCAL MAN ACQUIRES POSSUM. POSSUM SEEMINGLY UNFAZED.")
	_post("the possum follows me now. i don't know what this means."); host.unlock_achievement("the_route")
	return {"ok":true,"spawned":true}
func advance_wall(monotonic_ms: float) -> bool:
	if not is_finite(monotonic_ms) or monotonic_ms < _wall_ms or not _sync_epoch(): return false
	_wall_ms = monotonic_ms
	if _pet_due >= 0.0 and _wall_ms >= _pet_due:
		if not ready(): return false
		_pet_due = -1.0; spawn_pet_possum()
	return true
func _return_dog() -> bool:
	if not _actor("freed_dog_follower",true).is_empty(): _pending_dog.clear(); return true
	if _pending_dog.is_empty():
		_pending_dog = {"id":"freed_dog_follower","name":"THE DOG","sprite":"scrap_dog","x":host.p.x+(host.random_float()-0.5)*120.0,"y":host.p.y+80.0+host.random_float()*40.0,"w":26,"h":20,"color":"#684830","hp":40,"maxHp":40,"speed":1.4,"hostile":false,"archetype":"passive","isPet":true,"freedFollower":true,"frame":0}
	if not _place_actor(_pending_dog): return false
	var body: Dictionary = _pending_dog; _pending_dog = {}; _insert_actor(body,true)
	host.s.freedDogFollowT = 60000.0
	if not host.s.freedDogFirstReturn:
		host.s.freedDogFirstReturn = true
		_toast("the dog is back.\nhe is here.\nfor now.",3200); _post("the dog came back today. just for a while.")
	return true
func tick_world(dt_ms: float) -> bool:
	if not _valid_step(dt_ms) or not ready() or host.s.mode != "playing": return false
	if _actor("pet_possum",true).is_empty(): _pending_reveal.clear()
	if not _pending_pet.is_empty(): spawn_pet_possum()
	if host.s.quests.scrap_dog.state == "freed":
		var follower: Dictionary = _actor("freed_dog_follower",true)
		if not follower.is_empty():
			host.s.freedDogFollowT -= dt_ms
			if host.s.freedDogFollowT <= 0.0:
				_depart(follower); host.s.freedDogT = 90000.0+host.random_float()*180000.0
		elif not _pending_dog.is_empty(): _return_dog()
		else:
			host.s.freedDogT -= dt_ms
			if host.s.freedDogT <= 0.0: _return_dog()
	else: _pending_dog.clear()
	var dog: Dictionary = _actor("scrap_dog",true)
	if not dog.is_empty() and dog.get("chained",false):
		var near: bool = host.player_center().distance_squared_to(_center(dog)) < 10000.0
		dog.tailWag = clampf(float(dog.get("tailWag",0.0))+dt_ms*(0.003 if near else -0.002),0.0,1.0)
	return true
func _reveal_pending() -> bool:
	if _pending_reveal.is_empty(): return true
	var pile: Dictionary = _pending_reveal.pile
	var present: bool = false
	for current: Dictionary in host.cash_piles:
		if is_same(current,pile): present = true; break
	if not present or pile.get("collected",false): _pending_reveal.clear(); return true
	var spatial: Object = _object(_spatial_ref,&"stage_cash_pickup")
	if spatial == null: return false
	var origin: Vector2 = _pending_reveal.position
	var point: Variant = spatial.call(&"stage_cash_pickup",origin,RECOVERY_PX)
	if not _valid_point(point,origin): return false
	pile.x = point.x; pile.y = point.y; _pending_reveal.clear()
	host.emit_event("cash_revealed",{"pile_id":pile.id})
	_toast("the possum has placed something for you.\n(look around your feet.)",2400)
	return true
func tick_possum_reveal(body: Dictionary,dt_ms: float) -> bool:
	if not _valid_step(dt_ms) or not _sync_epoch() or body.get("id") != "pet_possum" or body.get("dead",false) or not is_same(_actor("pet_possum"),body): return false
	if not _pending_reveal.is_empty(): return _reveal_pending()
	if _object(_spatial_ref,&"stage_cash_pickup") == null: return false
	body.revealT = float(body.get("revealT",0.0))-dt_ms
	if body.revealT > 0.0: return true
	body.revealT = 30000.0+host.random_float()*15000.0
	var available: Array[Dictionary] = []
	for pile: Dictionary in host.cash_piles:
		if not pile.get("collected",false): available.append(pile)
	if available.is_empty(): return true
	var target: Dictionary = available[host.random_index(available.size())]
	_pending_reveal = {"pile":target,"position":Vector2(host.p.x+(host.random_float()-0.5)*60.0,host.p.y+40.0+host.random_float()*30.0)}
	return _reveal_pending()
func pending_snapshot() -> Dictionary:
	_sync_epoch()
	return {"pet_due":_pet_due,"pet":_pending_pet.duplicate(true),"dog":_pending_dog.duplicate(true),"reveal":_pending_reveal.duplicate(true)}
