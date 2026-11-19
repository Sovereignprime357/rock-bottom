class_name RockBottomBosses
extends RefCounted
## Encounter transitions and atomic special outcomes; Combat alone stages damage.
const Combat = preload("res://scripts/combat_system.gd")
var _host_ref: WeakRef
var _combat_ref: WeakRef
var _campaign_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var combat: RefCounted:
	get: return _combat_ref.get_ref() if _combat_ref != null else null
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _normalized: bool = false
var _wall_ms: float = 0.0
var _queue: Array[Dictionary] = []
var _serial: int = 0
var _missing: Dictionary = {}
var _old_school_pending: Dictionary = {}
var _old_school_serial: int = 0
var _old_school_preparing: bool = false

func _init(owner: RefCounted, combat_system: RefCounted, campaign_adapter: Object = null) -> void:
	_host_ref = weakref(owner); _combat_ref = weakref(combat_system)
	_campaign_ref = weakref(campaign_adapter) if campaign_adapter != null else null
	normalize_state()

func _sync_epoch() -> bool:
	if host == null or combat == null: return false
	if not is_same(_player_epoch, host.p) or not is_same(_state_epoch, host.s):
		_player_epoch = host.p; _state_epoch = host.s
		_normalized = false; _queue.clear(); _missing.clear(); _old_school_pending.clear()
	return true

func _campaign_has(method: StringName) -> bool:
	var adapter: Object = _campaign_ref.get_ref() if _campaign_ref != null else null
	return adapter != null and adapter.has_method(method)
func _campaign_call(method: StringName, args: Array = []) -> Variant:
	if not _campaign_has(method): return null
	return (_campaign_ref.get_ref() as Object).callv(method, args)
func _missing_once(key: String) -> void:
	if not _missing.has(key):
		_missing[key] = true; host.emit_event("dependency_missing", {"system":"bosses","key":key})
func _sound(id: String) -> void: host.emit_event("sound", {"id":id})
func _toast(text: String, duration: int = 2200) -> void: host.emit_event("toast", {"text":text,"duration_ms":duration})
func _feed(text: String, author: String = "@crackheadcent") -> void: host.emit_event("feed", {"text":text,"author":author})
func _news(text: String) -> void: host.emit_event("news", {"text":text})
func _save() -> void: host.emit_event("save_requested")
func _id(prefix: String) -> String:
	_serial += 1
	return "%s_3d_%d_%d" % [prefix,get_instance_id(),_serial]
func _actor(id: String) -> Dictionary: return combat.actor(id) if combat != null else {}
func _stage(body: Dictionary) -> Dictionary:
	var staged: Dictionary = body.duplicate(true)
	return staged if combat.clear_actor(staged) else {}
func _alive(body: Dictionary) -> bool: return not body.is_empty() and not body.get("dead", false)


func normalize_state() -> bool:
	if not _sync_epoch(): return false
	if _normalized: return true
	var ordinary: Dictionary = _actor("priest")
	var fallen: Dictionary = _actor("omalley_fallen")
	var is_fallen: bool = host.s.flags.get("omalleyFallen", false) == true
	var is_dead: bool = host.s.flags.get("omalleyFallenDead", false) == true
	var staged: Dictionary = {}
	if is_fallen and not is_dead:
		var source: Dictionary = ordinary if not ordinary.is_empty() else fallen
		if source.is_empty():
			for base: Dictionary in host.content.actors.base:
				if base.id == "priest": source = base.duplicate(true); break
		if source.is_empty(): _missing_once("restore_priest_definition"); return false
		staged = _fallen_record(source, true)
		staged = _stage(staged)
		if staged.is_empty(): _missing_once("restore_priest_placement"); return false
	# Only a new/load epoch clears encounter scratch. Calls during a live battle are idempotent.
	host.s.brutusOlderActive = false; host.s.brutusOlderNPC = null; host.s.brutusOlderPhase = 1
	if is_dead:
		for body: Dictionary in host.npcs:
			if body.id in ["priest","omalley_fallen"]: body.dead = true; body.hp = 0.0
	elif is_fallen:
		for index: int in range(host.npcs.size() - 1, -1, -1):
			if host.npcs[index].id in ["priest","omalley_fallen"]: host.npcs.remove_at(index)
		host.npcs.append(staged)
	_normalized = true
	return true


func can_start_tony() -> bool:
	return _sync_epoch() and not host.s.get("bossActive", false) and _alive(_actor("tony"))

func start_tony() -> bool: return _start_tony(false)
func start_coop() -> bool: return _start_tony(true)
func _start_tony(coop: bool) -> bool:
	if not normalize_state() or not can_start_tony(): return false
	var tony: Dictionary = _actor("tony")
	var staged: Dictionary = _stage(tony)
	if staged.is_empty(): return false
	var stripe: Dictionary = _actor("stripe") if coop else {}
	var ally: Dictionary = {}
	if not stripe.is_empty():
		ally = stripe.duplicate(true); ally.x = float(host.p.x) + 32.0; ally.y = host.p.y
		ally = _stage(ally)
		if ally.is_empty(): return false
	tony.x = staged.x; tony.y = staged.y
	tony.hostile = true; tony.aggro = true; tony.maxHp = 200; tony.hp = 200
	tony.speed = 1.8; tony.dmg = 12; tony.color = "#5a2018"; tony.coatsOff = 1
	host.s.bossActive = true; host.s.bossKind = "tony"; host.s.bossPhase = 1; host.s.bossNPC = tony
	if coop:
		host.s.coopMode = true
		if not stripe.is_empty():
			stripe.x = ally.x; stripe.y = ally.y; stripe.hp = 100; stripe.maxHp = 100; stripe.speed = 1.4
			stripe.isAlly = true; stripe.allyTarget = "tony"; stripe.hostile = false; stripe.aggro = false
			host.emit_event("actor_interaction_changed", {"actor_id":"stripe","kind":"coop_ally"})
		_toast("stripe walks beside you.\nthe corner is ahead.\ntony sees you.\nthen he sees stripe.\nthen he tears off the first coat.",4000)
		_news("ALLIANCE OBSERVED. TWO MEN. ONE WINDBREAKER. ONE CORNER.")
		_feed("teamed up with stripe. heading to tony. wish us anything.")
	else:
		_toast("tony tears off coat #1. then coat #2.\nthe corner is now arena.",3500)
		_news("BREAKING: TRE BAG TONY IS REMOVING COATS. NEIGHBORHOOD WATCHES.")
		_feed("tony is fighting at the corner. he had three coats. now two.","@the_corner")
	_sound("bossRoar")
	host.emit_event("boss_started", {"actor_id":"tony","coop":coop})
	return true


func spawn_brutus_older() -> bool:
	if not normalize_state() or host.s.get("brutusOlderActive", false): return false
	var previous: Dictionary = _actor("brutus_older")
	if _alive(previous): return false
	var loved: bool = host.p.faction.street >= 25
	var bounds: Dictionary = host.content.world.bounds
	var body: Dictionary = {"id":"brutus_older","name":"BRUTUS THE OLDER","sprite":"brutus",
		"x":clampf(float(host.p.x)+100.0,40.0,float(bounds.w)-80.0),"y":clampf(float(host.p.y)+100.0,40.0,float(bounds.h)-60.0),
		"w":48,"h":36,"color":"#8a3030","hp":200,"maxHp":200,"speed":2.4,"dmg":14,
		"hostile":not loved,"aggro":not loved,"isBossB":true,"showHp":true,"attackCd":0.0,"scale":1.5,
		"archetype":"passive" if loved else "charger_older","addsT":0.0}
	body = _stage(body)
	if body.is_empty(): return false
	for index: int in range(host.npcs.size()-1,-1,-1):
		if host.npcs[index].id == "brutus_older": host.npcs.remove_at(index)
	host.npcs.append(body)
	host.s.brutusOlderActive = true; host.s.brutusOlderNPC = body; host.s.brutusOlderPhase = 1
	_sound("bossRoar"); host.s.shake = 14.0
	host.emit_event("flash", {"color":"#a02828","alpha":0.4})
	if loved:
		_toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe sniffs once. he sits.\n(the block knows you.)",5400)
		_feed("the dog came back. he is bigger now. he did not charge.")
	else:
		_toast("BRUTUS RETURNS.\nhe is larger now.\nhis eyes are red.\nhe is ASCENDED.",4500)
		_feed("the dog came back. he is bigger now.")
	_news("BRUTUS HAS RETURNED. WITNESSES DESCRIBE 'LARGER. REDDER.'")
	host.emit_event("actor_spawned", {"actor_id":body.id})
	return true


func _fallen_record(source: Dictionary, reset_scratch: bool = false) -> Dictionary:
	var body: Dictionary = source.duplicate(true)
	body.id = "omalley_fallen"; body.name = "FATHER O'MALLEY (FALLEN)"; body.archetype = "priest_fallen"
	body.hostile = true; body.aggro = true; body.dead = false
	body.maxHp = 160; body.hp = 160; body.speed = 1.6; body.dmg = 22; body.color = "#2a1a2a"
	body.showHp = true; body.isOmalleyFallen = true; body.attackCd = 0.0
	body.chargeState = "idle"; body.chargeT = 0.0; body.chargeCdT = 0.0
	if reset_scratch:
		for key: String in ["hitFlash","hitStun","throwT","throwAimT"]: body[key] = 0.0
		body.aimingThrow = false; body.fallenPhase2 = false
	return body

func transform_fallen_priest() -> bool:
	if not normalize_state() or host.s.flags.get("omalleyFallen", false): return false
	var ordinary: Dictionary = _actor("priest")
	if not _alive(ordinary): return false
	var staged: Dictionary = _stage(_fallen_record(ordinary))
	if staged.is_empty(): return false
	ordinary.merge(staged, true)
	host.s.flags.omalleyFallen = true
	if not host.s.quests.fallen_priest.done: host.s.quests.fallen_priest.available = true
	_sound("bossRoar"); host.s.shake = 14.0
	host.emit_event("flash", {"color":"#78288c","alpha":0.35})
	_toast("father o'malley does not stand up.\nhe is already standing.\nthe collar comes off.\nthe smile is wrong.",5500)
	_news("PRIEST AT CHURCH 'NOT BEHAVING AS EXPECTED.' WITNESSES UNCLEAR.")
	_feed("father o'malley turned. the collar is on the floor.")
	host.emit_event("actor_transformed", {"from_id":"priest","actor_id":"omalley_fallen"})
	_save()
	return true


func spawn_old_school_brutus() -> bool:
	if not normalize_state() or not _actor("os_brutus").is_empty(): return false
	var plan: Dictionary = prepare_old_school_brutus()
	if not plan.get("ok",false):
		if plan.get("reason") == "missing_definition": _missing_once("old_school_door")
		return false
	return commit_old_school_brutus(plan)

func prepare_old_school_brutus() -> Dictionary:
	if _old_school_preparing: return {"ok":false,"reason":"preparing"}
	if not _sync_epoch() or not _normalized: return {"ok":false,"reason":"state_not_normalized"}
	_old_school_pending.clear()
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	var door: Dictionary = host.definition("src/dialogue/vendors_places.js","OLD_SCHOOL_DOOR",{})
	if door.is_empty(): return {"ok":false,"reason":"missing_definition"}
	var noop: bool = not _actor("os_brutus").is_empty()
	var body: Dictionary = {"id":"os_brutus","name":"OLD SCHOOL BRUTUS","sprite":"os_brutus",
		"x":float(door.x)-30.0,"y":float(door.y)+80.0,"w":36,"h":28,"color":"#604030",
		"hp":250,"maxHp":250,"speed":1.5,"hostile":true,"aggro":true,"dmg":35,"archetype":"charger","showHp":true,
		"chargeState":"idle","chargeT":0.0,"grabFreezeT":0.0,"isOsBrutus":true}
	if not noop:
		_old_school_preparing = true
		body = _stage(body)
		_old_school_preparing = false
		# Physical adapters are external. Neither replacement p nor s may receive
		# the prepared actor or any follow-on reward from an old action.
		if not is_same(host.p,player_epoch) or not is_same(host.s,state_epoch): return {"ok":false,"reason":"replaced_state"}
		if body.is_empty(): return {"ok":false,"reason":"blocked_placement"}
		noop = not _actor("os_brutus").is_empty()
	_old_school_serial += 1
	var token: String = "%d:os:%d" % [get_instance_id(),_old_school_serial]
	_old_school_pending = {"token":token,"player":player_epoch,"state":state_epoch,"body":{} if noop else body,"noop":noop}
	return {"ok":true,"token":token,"noop":noop}

func discard_old_school_brutus(plan: Dictionary) -> void:
	if not _old_school_pending.is_empty() and plan.get("token") == _old_school_pending.get("token"): _old_school_pending.clear()

func commit_old_school_brutus(plan: Dictionary) -> bool:
	if host == null or _old_school_pending.is_empty() or plan.get("token") != _old_school_pending.get("token"): return false
	var pending: Dictionary = _old_school_pending
	_old_school_pending = {} # consume before effects; stale callers cannot erase a newer plan.
	if not is_same(host.p,pending.player) or not is_same(host.s,pending.state): return false
	if not _actor("os_brutus").is_empty(): return true # Exact source duplicate/corpse no-op.
	if pending.noop or pending.body.is_empty(): return false
	var body: Dictionary = pending.body
	host.npcs.append(body)
	_toast("OLD SCHOOL BRUTUS is loose.\nhe was sleeping in the gym.\nhe is no longer sleeping.",4200)
	_feed("@blocklog: old school brutus is up. someone tore copper out of the gym.","@blocklog")
	_sound("glassBreak"); _save(); host.emit_event("actor_spawned", {"actor_id":body.id})
	return true


func tick_before_actors(dt_ms: float) -> bool:
	if not normalize_state() or not Combat.valid_step(dt_ms): return false
	var exists: bool = false
	for body: Dictionary in host.npcs:
		if body.get("isOmalleyFallen", false) and not body.get("dead", false): exists = true; break
	host.s.counters.omalleyFallenSurviveT = float(host.s.counters.get("omalleyFallenSurviveT",0.0)) + dt_ms if exists else 0.0
	if host.s.counters.omalleyFallenSurviveT >= 60000.0: host.unlock_achievement("outran_the_priest")
	return true


func _sherri(x: float, y: float, prefix: String) -> Dictionary:
	return _stage({"id":_id(prefix),"name":"SPIDER-BITE SHERRI","sprite":"sherri","x":x,"y":y,
		"w":26,"h":30,"color":"#3a1820","hp":45,"maxHp":45,"speed":2.0,"hostile":true,"aggro":true,
		"aggroOnHit":true,"dmg":5,"archetype":"swarmer","attackCd":0.0,"showHp":false,"transient":true})

func tick_after_actors(dt_ms: float, wall_ms: float) -> bool:
	if not normalize_state() or not Combat.valid_step(dt_ms) or not is_finite(wall_ms) or wall_ms < _wall_ms: return false
	_wall_ms = wall_ms
	if host.s.get("bossKind") == "tony" and host.s.get("bossActive",false):
		var body: Dictionary = host.s.get("bossNPC",{}) if host.s.get("bossNPC") is Dictionary else {}
		if _alive(body): _tony_phase(body)
	if host.s.get("brutusOlderActive",false):
		var body: Dictionary = host.s.get("brutusOlderNPC",{}) if host.s.get("brutusOlderNPC") is Dictionary else {}
		if _alive(body): _older_phase(body,dt_ms)
	return true

func _tony_phase(body: Dictionary) -> void:
	var pct: float = float(body.hp) / float(body.maxHp)
	var next: int = int(host.s.bossPhase)
	if pct < 0.66 and host.s.bossPhase < 2: next = 2
	if pct < 0.33 and host.s.bossPhase < 3: next = 3
	if next == host.s.bossPhase: return
	var adds: Array[Dictionary] = []
	if next == 2:
		var left := _sherri(float(body.x)-80.0,float(body.y),"sherri_boss")
		var right := _sherri(float(body.x)+80.0,float(body.y),"sherri_boss")
		if left.is_empty() or right.is_empty(): _missing_once("tony_add_placement"); return
		adds.append(left); adds.append(right)
	host.s.bossPhase = next; body.coatsOff = next; body.archetype = "charger"
	body.chargeState = "idle"; body.chargeT = 0.0; body.chargeCdT = 0.0
	if next == 2:
		body.speed = 2.4
		for add: Dictionary in adds:
			host.npcs.append(add); host.emit_event("actor_spawned", {"actor_id":add.id})
		_toast("tony tears off coat #2.\nhe is faster now.\nhe whistles. someone answers.",3200)
		_news("BREAKING: TRE BAG TONY DOWN TO 2 COATS. SOMETHING ELSE IS COMING.")
		_feed("tony is on coat 2. and somebody else just showed up.","@the_corner")
	else:
		body.berserk = true; body.speed = 3.0; body.dmg = 16
		_toast("tony tears off coat #3.\nhe is not slowing down.\nhe is speeding up.",3500)
		_sound("bossRoar")
		_queue.append({"kind":"roar","due":_wall_ms+200.0}); _queue.append({"kind":"roar","due":_wall_ms+420.0})
		_news("BREAKING: TRE BAG TONY BARE-KNUCKLE. CALL TIME OF DEATH ALREADY.")
		_feed("tony has no coats. tony is lunging now. like a dog.","@the_corner")
	_sound("bossRoar"); host.s.shake = 12.0
	host.emit_event("boss_phase_changed", {"actor_id":body.id,"phase":next,"coats_off":body.coatsOff})

func _older_phase(body: Dictionary, dt: float) -> void:
	var pct: float = float(body.hp) / float(body.maxHp)
	var current: int = int(host.s.get("brutusOlderPhase",1))
	var next: int = current
	if pct < 0.5 and current < 2: next = 2
	if pct < 0.25 and current < 3: next = 3
	if next != current:
		host.s.brutusOlderPhase = next; _sound("bossRoar"); host.s.shake = 12.0
		if next == 2: body.addsT = 0.0; _toast("he was warming up before.",3000)
		else:
			body.berserk = true; body.grabber = true; body.chargeState = "idle"
			_toast("he doesn't bite anymore.\nhe grabs.",3200)
		host.emit_event("boss_phase_changed", {"actor_id":body.id,"phase":next})
	if host.s.brutusOlderPhase >= 2:
		body.addsT = float(body.get("addsT",0.0)) + dt
		if body.addsT >= 8000.0:
			body.addsT = 0.0
			var count: int = 0
			for actor: Dictionary in host.npcs:
				if actor.get("archetype") == "swarmer" and not actor.get("dead",false): count += 1
			if count < 2:
				var add := _sherri(float(body.x)-60.0,float(body.y)+20.0,"sherri_brutus")
				if add.is_empty(): _missing_once("older_add_placement")
				else: host.npcs.append(add); host.emit_event("actor_spawned", {"actor_id":add.id})
	if host.s.brutusOlderPhase >= 3 and body.get("chargeLanded",false):
		body.chargeLanded = false; host.p.stunT = maxf(float(host.p.stunT),500.0)


func can_handle_death(body: Dictionary) -> bool:
	if not _sync_epoch() or body.is_empty() or body.get("dead",false): return false
	if body.get("kingdomBoss",false) or body.get("kingdomPretender",false):
		if not _campaign_has(&"can_finish_actor") or not _campaign_has(&"finish_actor"): return false
		var answer: Variant = _campaign_call(&"can_finish_actor",[body.duplicate(true)])
		return answer is bool and answer
	return body.get("isOmalleyFallen",false) or body.get("id") == "os_brutus" or (body.get("id") == "brutus_older" and body.get("isBossB",false)) or (body.get("id") == "tony" and host.s.bossActive and host.s.bossKind == "tony")

func handle_death(id: String) -> bool:
	if not _sync_epoch(): return false
	var body: Dictionary = _actor(id)
	if body.is_empty() or body.get("dead",false) or float(body.get("hp",1.0)) > 0.0 or not can_handle_death(body): return false
	if body.get("kingdomBoss",false) or body.get("kingdomPretender",false):
		var result: Variant = _campaign_call(&"finish_actor",[id])
		return result is bool and result
	body.dead = true; _sound("hurt"); host.emit_event("actor_died", {"actor_id":id})
	match id:
		"tony": _tony_dead(body)
		"brutus_older": _older_dead()
		"os_brutus": _old_school_dead(body)
		_: _fallen_dead(body)
	return true

func _weapon(id: String) -> void:
	var entry: Dictionary = host.content.catalogs.weapons[id]
	host.p.weapon = id
	_toast("+ " + str(entry.n) + "\n(equipped.)")
	_feed("picked up " + str(entry.n) + ". things are escalating.")
func _pile(body: Dictionary, amount: int, offset: float, extra: Dictionary = {}) -> void:
	var pile: Dictionary = {"id":_id("cp_"+str(body.id)),"x":float(body.x)+float(body.w)*0.5+offset,
		"y":float(body.y)+float(body.h)*0.5+8.0,"amt":amount,"collected":false}
	pile.merge(extra,true); host.cash_piles.append(pile)
func _quest(title: String) -> void: _toast("· QUEST COMPLETE ·\n"+title); _sound("rankUp")

func _tony_dead(_body: Dictionary) -> void:
	host.s.bossActive = false; host.s.bossKind = ""; host.s.bossPhase = 0; host.s.bossNPC = null
	host.p.cred += 200; host.s.quests.fallen_king.done = true; _quest("THE FALLEN KING")
	if _campaign_has(&"after_tony_defeat"):
		var answer: Variant = _campaign_call(&"after_tony_defeat")
		if not answer is bool or not answer: _missing_once("after_tony_defeat")
	else: _missing_once("after_tony_defeat")
	_weapon("shoe")
	var coop: bool = host.s.get("coopMode",false)
	_toast("tony is on the ground.\nstripe nods. 'good. tuesdays and thursdays. as agreed.'" if coop else "tony is on the ground.\nthe corner is yours.\nyou get tuesdays and thursdays.",5500)
	_save()
	_queue.append({"kind":"ending","ending":"coop" if coop else "tony","due":_wall_ms+4000.0})

func _older_dead() -> void:
	host.s.brutusOlderActive = false; host.p.cred += 100; host.p.maxHp += 5
	_toast("BRUTUS THE OLDER IS DOWN.\nyou get +5 max hp.\n(it is called BRUTUS'S COLLAR.)\nyou are wearing the collar now.",5500)
	_news("BRUTUS THE OLDER DEFEATED. NEIGHBORHOOD UNCERTAIN HOW TO FEEL.")
	_feed("the dog returned. then he didn't. legend.")
	# Source returns here without immediate save or creating an equipment item.

func _old_school_dead(body: Dictionary) -> void:
	host.p.cred += 50; host.apply_rep({"street":2})
	var multiplier: float = float(host.s.get("territoryCashMult",1.0))
	if multiplier == 0.0: multiplier = 1.0
	_pile(body,int(floor(80.0*multiplier+0.5)),-22.0)
	host.p.copper += 5; host.s.counters.copperStripped = int(host.s.counters.get("copperStripped",0)) + 5
	if host.s.counters.copperStripped >= 10: host.unlock_achievement("copper_singer")
	if not combat.inventory.owns_tool("propane_torch"): _pile(body,0,22.0,{"tool":"propane_torch"})
	host.unlock_achievement("school_s_out"); host.s.flags.osBrutusKilled = true
	_toast("OLD SCHOOL BRUTUS IS DOWN.\n+ $80. + 5 copper. + a torch he had on him.\nthe gym is finally quiet.",5500)
	_news("THE OLD SCHOOL IS QUIET. SOMETHING LARGE NO LONGER LIVES IN THE GYM.")
	_feed("school's out. the old school is empty. the copper is gone.","@blocklog"); _save()

func _fallen_dead(body: Dictionary) -> void:
	host.s.flags.omalleyFallenDead = true; host.apply_rep({"street":2})
	_pile(body,200,-18.0); _pile(body,0,18.0,{"equip":"priest_collar"})
	if not host.s.quests.fallen_priest.done:
		host.s.quests.fallen_priest.done = true; host.s.quests.fallen_priest.available = false; _quest("THE FALLEN PRIEST")
	host.unlock_achievement("fallen")
	_toast("the church is quiet again.\nthe pews are still wrong.",4200)
	_news("PRIEST 'GONE'. CHURCH 'WEIRD NOW'. WITNESSES VAGUE.")
	_feed("the priest is on the ground. the collar is on the floor. you have both."); _save()


func tick_wall(wall_ms: float) -> bool:
	if not _sync_epoch() or not is_finite(wall_ms) or wall_ms < _wall_ms: return false
	_wall_ms = wall_ms
	var pending: Array[Dictionary] = []
	for task: Dictionary in _queue:
		if float(task.due) > wall_ms: pending.append(task); continue
		if task.kind == "roar": _sound("bossRoar")
		elif task.kind == "ending":
			host.s.mode = "title"; host.s.endingContinue = true
			host.emit_event("ending_requested", {"kind":task.ending}); _save()
	_queue = pending
	return true
