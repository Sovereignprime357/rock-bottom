class_name RockBottomCombat
extends RefCounted
## Source combat transactions. Physics and domain adapters never own player resources.
const Inventory = preload("res://scripts/inventory.gd")
const MAX_STEP_MS := 50.0
const COP_CAP := 4
var _host_ref: WeakRef
var _physics_ref: WeakRef
var _domain_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _wall_ms: float = 0.0
var _serial: int = 0
var _wall_queue: Array[Dictionary] = []
var _missing: Dictionary = {}
var _prop_attack_ref: WeakRef
var _prop_swing: Dictionary = {}
var _prop_swing_serial: int = 0


func _init(owner: RefCounted, physics_adapter: Object, owned_inventory: RefCounted = null, domain_adapter: Object = null) -> void:
	_host_ref = weakref(owner)
	_physics_ref = weakref(physics_adapter) if physics_adapter != null else null
	_domain_ref = weakref(domain_adapter) if domain_adapter != null else null
	inventory = owned_inventory if owned_inventory != null else Inventory.new(owner)
	_sync_epoch()


func _sync_epoch() -> bool:
	if host == null: return false
	if not is_same(_player_epoch, host.p) or not is_same(_state_epoch, host.s):
		_player_epoch = host.p; _state_epoch = host.s
		_wall_queue.clear(); _missing.clear(); _prop_swing.clear()
	return true

func set_prop_attack_owner(owner: Object) -> bool:
	_prop_swing.clear()
	if owner == null: _prop_attack_ref = null; return true
	if not owner.has_method(&"resolve_swing") or not owner.has_method(&"bind_combat"): return false
	_prop_attack_ref = weakref(owner)
	owner.call(&"bind_combat",self)
	return true

func consume_prop_swing(token: Variant,candidates: Array,consumer: Object) -> Dictionary:
	if not token is String or _prop_swing.is_empty() or token != _prop_swing.token: return {"ok":false,"reason":"stale_swing"}
	var captured: Dictionary = _prop_swing; _prop_swing = {}
	var bound: Object = _prop_attack_ref.get_ref() if _prop_attack_ref != null else null
	if consumer == null or not is_same(consumer,bound): return {"ok":false,"reason":"wrong_consumer"}
	if host == null or not is_same(captured.player,host.p) or not is_same(captured.state,host.s): return {"ok":false,"reason":"replaced_state"}
	var hits: Array[String] = []
	for raw: Variant in candidates:
		if not raw is Dictionary or not raw.get("id") is String: continue
		var valid: bool = true
		for key: String in ["x","y","w","h"]: valid = valid and finite_number(raw.get(key))
		if not valid or float(raw.w) <= 0 or float(raw.h) <= 0 or hits.has(raw.id): continue
		if not _swing_overlaps(raw,captured.origin,captured.forward,captured.reach): continue
		var clear: bool = can_hit(captured.center,center(raw),"player",raw.id)
		if not is_same(captured.player,host.p) or not is_same(captured.state,host.s): return {"ok":false,"reason":"replaced_state"}
		if clear: hits.append(raw.id)
	return {"ok":true,"hits":hits}

func _resolve_prop_swing(origin: Vector2,forward: Vector2,reach: float,player_epoch: Dictionary,state_epoch: Dictionary) -> void:
	var owner: Object = _prop_attack_ref.get_ref() if _prop_attack_ref != null else null
	if owner == null or not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return
	_prop_swing_serial += 1
	var token := "%d:prop-swing:%d" % [get_instance_id(),_prop_swing_serial]
	_prop_swing = {"token":token,"player":player_epoch,"state":state_epoch,"origin":origin,"forward":forward,"reach":reach,"center":host.player_center()}
	owner.call(&"resolve_swing",token)
	_prop_swing.clear()


func actor(id: String) -> Dictionary:
	if host != null:
		for body: Dictionary in host.npcs:
			if body.get("id") == id: return body
	return {}


static func center(body: Dictionary) -> Vector2:
	return Vector2(float(body.get("x", 0.0)) + float(body.get("w", 0.0)) * 0.5, float(body.get("y", 0.0)) + float(body.get("h", 0.0)) * 0.5)


static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func valid_step(dt: float) -> bool:
	return is_finite(dt) and dt > 0.0 and dt <= MAX_STEP_MS


static func overlaps(a: Dictionary, b: Dictionary, margin: float = 0.0) -> bool:
	return float(a.x) - margin < float(b.x) + float(b.w) and float(a.x) + float(a.w) + margin > float(b.x) and float(a.y) - margin < float(b.y) + float(b.h) and float(a.y) + float(a.h) + margin > float(b.y)


func _physics() -> Object:
	return _physics_ref.get_ref() if _physics_ref != null else null


func has_physics(method: StringName) -> bool:
	var adapter: Object = _physics()
	return adapter != null and adapter.has_method(method)


func _geometry(body: Dictionary) -> Dictionary:
	var result: Dictionary = {"id":str(body.get("id", "player")), "x":body.x, "y":body.y, "w":body.w, "h":body.h}
	# Detached visual hints let first placement use the actual profile height before
	# a spawned actor enters the model roster or receives its presentation node.
	for key: String in ["name","sprite"]:
		if body.get(key) is String: result[key] = body[key]
	if body.get("isOmalleyFallen") is bool: result.isOmalleyFallen = body.isOmalleyFallen
	return result


func clear_actor(body: Dictionary) -> bool:
	if not has_physics(&"clear_placement"): return false
	var result: Variant = _physics().call(&"clear_placement", _geometry(body))
	if not result is Vector2 or not result.is_finite(): return false
	body.x = result.x; body.y = result.y
	return true


func move_actor(body: Dictionary, intended: Vector2, goal: Variant = null, stop_on_block: bool = false) -> Dictionary:
	var origin := Vector2(float(body.x), float(body.y))
	if not intended.is_finite() or not has_physics(&"move_body"): return {"position":origin, "blocked":true, "failed":true}
	if goal != null and (not goal is Vector2 or not goal.is_finite()): return {"position":origin, "blocked":true, "failed":true}
	var result: Variant = _physics().call(&"move_body", _geometry(body), intended, goal, stop_on_block)
	if not result is Dictionary or not result.get("position") is Vector2 or not result.position.is_finite() or not result.get("blocked") is bool:
		return {"position":origin, "blocked":true, "failed":true}
	body.x = result.position.x; body.y = result.position.y
	return {"position":result.position, "blocked":result.blocked, "failed":false}


func can_hit(from: Vector2, to: Vector2, source_id: String, target_id: String) -> bool:
	if not from.is_finite() or not to.is_finite() or not has_physics(&"can_hit"): return false
	var result: Variant = _physics().call(&"can_hit", from, to, source_id, target_id)
	return result is bool and result


func resolve_departure(body: Dictionary, edge: String) -> Dictionary:
	if host == null or edge not in ["east","west"] or not has_physics(&"resolve_departure"): return {}
	var result: Variant = _physics().call(&"resolve_departure", _geometry(body), edge)
	if not result is Dictionary or not result.get("exit_id") is String or result.exit_id.is_empty(): return {}
	if not result.get("target") is Vector2 or not result.target.is_finite() or not result.get("route") is Array: return {}
	if result.route.is_empty() or result.route.size() > 2048: return {}
	var bounds: Dictionary = host.content.world.bounds
	var half := Vector2(float(body.w),float(body.h))*0.5
	var limit := Vector2(float(bounds.w),float(bounds.h))-half
	var route: Array[Vector2] = []
	for point: Variant in result.route:
		if not point is Vector2 or not point.is_finite() or point.x < half.x or point.y < half.y or point.x > limit.x or point.y > limit.y: return {}
		route.append(point)
	if route[-1].distance_squared_to(result.target) > 0.00000001: return {}
	return {"exit_id":result.exit_id,"target":result.target,"route":route}


func domain_has(method: StringName) -> bool:
	var adapter: Object = _domain_ref.get_ref() if _domain_ref != null else null
	return adapter != null and adapter.has_method(method)


func domain_call(method: StringName, arguments: Array = []) -> Variant:
	if not domain_has(method): return null
	return (_domain_ref.get_ref() as Object).callv(method, arguments)


func dependency_missing(key: String) -> void:
	if not _missing.has(key):
		_missing[key] = true
		host.emit_event("dependency_missing", {"system":"combat", "key":key})


func _id(prefix: String) -> String:
	_serial += 1
	return "%s_3d_%d_%d" % [prefix, get_instance_id(), _serial]


func _sound(id: String) -> void: host.emit_event("sound", {"id":id})
func _toast(text: String, duration_ms: int = 2200) -> void: host.emit_event("toast", {"text":text, "duration_ms":duration_ms})
func _feed(text: String, author: String = "@crackheadcent") -> void: host.emit_event("feed", {"text":text, "author":author})
func _save() -> void: host.emit_event("save_requested")


func _swing_overlaps(body: Dictionary, origin: Vector2, forward: Vector2, reach: float) -> bool:
	# SAT for the rotated source 8px-wide rectangle and the actor's source AABB.
	var side := Vector2(-forward.y, forward.x)
	var swing_center := origin + forward * reach * 0.5
	var delta := center(body) - swing_center
	var half := Vector2(float(body.w), float(body.h)) * 0.5
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, forward, side]:
		var body_radius: float = absf(axis.x) * half.x + absf(axis.y) * half.y
		var swing_radius: float = absf(axis.dot(forward)) * reach * 0.5 + absf(axis.dot(side)) * 4.0
		if absf(delta.dot(axis)) >= body_radius + swing_radius: return false
	return true


func attack_player(horizontal_forward: Vector2) -> Dictionary:
	if not _sync_epoch() or host.s.mode != "playing" or float(host.p.stunT) > 0.0 or float(host.p.attackCd) > 0.0: return {"ok":false, "reason":"unavailable"}
	if not horizontal_forward.is_finite() or horizontal_forward.length_squared() < 0.000001: return {"ok":false, "reason":"invalid_direction"}
	if not has_physics(&"can_hit") or not has_physics(&"move_body"): return {"ok":false, "reason":"missing_physics"}
	var forward := horizontal_forward.normalized()
	var used_weapon: String = str(host.p.weapon)
	var weapon: Dictionary = host.content.catalogs.weapons.get(used_weapon, host.content.catalogs.weapons.fists)
	var reach: float = 36.0 + float(weapon.get("reach", 0.0))
	var front: float = absf(forward.x) * float(host.p.w) * 0.5 + absf(forward.y) * float(host.p.h) * 0.5
	var origin: Vector2 = host.player_center() + forward * front
	var swing_player: Dictionary = host.p; var swing_state: Dictionary = host.s
	host.p.attackCd = float(weapon.cd); host.p.attacking = 160.0
	_sound("hit")
	var connected: bool = false
	var rewardable: bool = false
	var hits: Array[String] = []
	for body: Dictionary in host.npcs.duplicate():
		if not is_same(swing_player,host.p) or not is_same(swing_state,host.s): return {"ok":false,"reason":"replaced_state"}
		if body.get("dead", false) or not _swing_overlaps(body, origin, forward, reach): continue
		var clear: bool = can_hit(host.player_center(), center(body), "player", str(body.id))
		if not is_same(swing_player,host.p) or not is_same(swing_state,host.s): return {"ok":false,"reason":"replaced_state"}
		if not clear: continue
		if body.get("essential", false):
			body.hitFlash = 120.0; body.showHp = false
			host.s.shake = maxf(float(host.s.get("shake", 0.0)), 2.0); host.s.hitPause = 20.0
			if float(body.get("essentialToastAt", 0.0)) <= _wall_ms:
				body.essentialToastAt = _wall_ms + 2500.0
				_toast(str(body.name) + " enters the hit as a clerical error.\nno displacement authorized.", 1800)
			host.emit_event("essential_contact", {"actor_id":body.id})
			continue
		var vulnerability: float = 1.25 if body.get("archetype") in ["charger", "charger_older"] and body.get("chargeState") == "cooldown" else 1.0
		var damage: int = int(floor((14.0 + host.random_float() * 8.0 + float(weapon.dmg)) * (1.5 if host.p.rockedT > 0 else 1.0) * (1.3 if host.p.cartMounted else 1.0) * vulnerability))
		if not _subtract_hp(body, damage): continue
		body.showHp = true; body.hitFlash = 200.0; body.hitStun = 120.0
		connected = true; rewardable = rewardable or not body.get("noComboReward", false)
		hits.append(str(body.id))
		host.s.shake = maxf(float(host.s.get("shake", 0.0)), 4.0); host.s.hitPause = 40.0
		if body.id == "scrap_dog" and body.get("chained", false): _hit_chained_dog(body)
		if not body.get("hostile", false) and not body.get("aggroOnHit", false):
			host.p.wanted = mini(3, int(host.p.wanted) + 1)
			_toast(str(body.name) + " did not deserve that.\nwanted +1")
		if body.get("aggroOnHit", false) and not body.get("aggro", false):
			body.hostile = true; body.aggro = true
			if body.get("archetype") == "swarmer" and body.id == "sherri": spawn_swarmer(body)
		if not is_same(swing_player,host.p) or not is_same(swing_state,host.s): return {"ok":false,"reason":"replaced_state"}
		move_actor(body, Vector2(body.x, body.y) + forward * 8.0)
		if not is_same(swing_player,host.p) or not is_same(swing_state,host.s): return {"ok":false,"reason":"replaced_state"}
		host.emit_event("actor_hit", {"actor_id":body.id, "damage":damage, "weapon":host.p.weapon})
		if body.hp <= 0: kill_actor(body.id)
	_resolve_prop_swing(origin,forward,reach,swing_player,swing_state)
	if not is_same(swing_player,host.p) or not is_same(swing_state,host.s): return {"ok":false,"reason":"replaced_state"}
	if rewardable:
		host.s.combo += 1; host.s.comboT = 1800.0
		if host.s.combo >= 3: host.s.shake = maxf(float(host.s.get("shake", 0.0)), 6.0)
		if host.s.combo == 5:
			host.p.cred += 3; _toast("· 5x COMBO ·\n+ 3 cred", 1400); host.unlock_achievement("not_a_phase")
		elif host.s.combo == 10: host.p.cred += 10; _toast("· 10x COMBO ·\n+ 10 cred", 1600)
	else:
		host.s.combo = 0
		if connected: host.s.comboT = 0.0
	if _prop_attack_ref == null or _prop_attack_ref.get_ref() == null:
		host.emit_event("attack_props_requested", {"origin":origin, "forward":forward, "reach":reach, "width":8.0})
	host.emit_event("player_attack", {"hits":hits, "connected":connected, "used_weapon":used_weapon})
	return {"ok":true, "connected":connected, "hits":hits}


func _hit_chained_dog(body: Dictionary) -> void:
	var quest: Dictionary = host.s.quests.scrap_dog
	quest.state = "left"; quest.done = true; quest.available = false
	if not host.s.achievements.has("the_piece_of_shit"):
		host.p.cred = maxi(-50, int(host.p.cred) - 5)
		host.unlock_achievement("the_piece_of_shit")
		_toast("the dog growls. low. wrong.\nyou hit a dog that was tied up.\n- 5 cred", 4000)
		_feed("there is a piece of shit out there. it is the man on the corner.")
	body.hostile = true; body.aggro = true; body.chained = false; body.speed = 1.6; body.dmg = 6
	_sound("hurt"); _save()


func damage_player(amount: float, source: Dictionary = {}) -> Dictionary:
	if host == null or not is_finite(amount) or amount <= 0.0 or float(host.p.iframes) > 0.000001: return {"applied":false, "fatal":false}
	if not source.is_empty() and not can_hit(center(source), host.player_center(), str(source.get("id", "")), "player"): return {"applied":false, "fatal":false}
	return _hurt_player(amount, source)


func _hurt_player(amount: float, source: Dictionary) -> Dictionary:
	if float(host.p.iframes) > 0.000001: return {"applied":false, "fatal":false}
	var cash_before: int = int(host.p.cash)
	var fatal: bool = host.hurt(amount, source)
	_sound("hurt")
	host.emit_event("flash", {"color":"#a02828", "alpha":0.4})
	host.s.shake = 8.0
	if not fatal and not source.is_empty():
		var away := Vector2(float(host.p.x) - float(source.x), float(host.p.y) - float(source.y))
		move_actor(host.p, Vector2(host.p.x, host.p.y) + away / (away.length() if away.length() > 0.0 else 1.0) * 8.0)
	if fatal:
		if source.get("isCop", false):
			_toast("arrested.\n- $%d · - all rocks\nthey didn't check your sock." % (cash_before - int(host.p.cash)), 4000)
			_feed("arrested again. they did not check the sock. the sock is safe.")
		else:
			_sound("death")
			_toast("you wake up at the block.\nyour mouth tastes like a battery.\nit is approximately tuesday.", 3500)
	return {"applied":true, "fatal":fatal}


func _special_death(body: Dictionary) -> bool:
	return body.get("kingdomBoss", false) or body.get("kingdomPretender", false) or body.get("isOmalleyFallen", false) or body.id == "os_brutus" or (body.id == "brutus_older" and body.get("isBossB", false)) or (body.id == "tony" and host.s.bossActive and host.s.bossKind == "tony")


func _death_ready(body: Dictionary) -> bool:
	if not _special_death(body): return true
	if domain_has(&"can_handle_death") and domain_has(&"handle_death"):
		var answer: Variant = domain_call(&"can_handle_death", [body.duplicate(true)])
		if answer is bool and answer: return true
	dependency_missing("death:" + str(body.id))
	return false


func damage_actor(id: String, amount: float, flash_ms: float = 180.0) -> bool:
	var body: Dictionary = actor(id)
	if body.is_empty() or body.get("dead", false) or body.get("essential", false) or not is_finite(amount) or amount <= 0.0: return false
	if not is_finite(flash_ms) or flash_ms < 0.0 or not _subtract_hp(body, amount): return false
	body.hitFlash = flash_ms; body.showHp = true
	if body.hp <= 0: kill_actor(id)
	return true


func _subtract_hp(body: Dictionary, amount: float) -> bool:
	var previous: float = float(body.hp)
	if amount >= previous and _special_death(body):
		if not _death_ready(body): return false
		body.hp = previous - amount
		# The domain owns its whole completion transaction; a false result must be pure.
		var answer: Variant = domain_call(&"handle_death", [body.id])
		if not answer is bool or not answer:
			body.hp = previous
			return false
		return true
	body.hp = previous - amount
	return true


func tick_status(dt_ms: float) -> bool:
	if not _sync_epoch() or not valid_step(dt_ms): return false
	if float(host.s.get("comboT", 0.0)) > 0.0:
		host.s.comboT = maxf(0.0, float(host.s.comboT) - dt_ms)
		if host.s.comboT <= 0.0: host.s.combo = 0
	return true


func _pickup_weapon(id: String) -> void:
	var weapon: Dictionary = host.content.catalogs.weapons.get(id, {})
	if weapon.is_empty(): return
	host.p.weapon = id
	_toast("+ " + str(weapon.n) + "\n(equipped.)")
	_feed("picked up " + str(weapon.n) + ". things are escalating.")


func _drop(body: Dictionary, amount: int, fields: Dictionary = {}, prefix: String = "cp_drop") -> void:
	var pile: Dictionary = {"id":_id(prefix), "x":float(body.x) + float(body.w) * 0.5, "y":float(body.y) + float(body.h) * 0.5 + 8.0, "amt":amount, "collected":false}
	pile.merge(fields, true)
	host.cash_piles.append(pile)


func kill_actor(id: String) -> bool:
	if not _sync_epoch(): return false
	var body: Dictionary = actor(id)
	if body.is_empty() or body.get("dead", false) or float(body.get("hp", 1)) > 0.0: return false
	if body.get("essential", false): body.dead = false; body.hp = body.maxHp; return false
	if _special_death(body):
		if not _death_ready(body): return false
		var answer: Variant = domain_call(&"handle_death", [id])
		return answer is bool and answer
	body.dead = true
	_sound("hurt")
	host.emit_event("actor_died", {"actor_id":id})
	if body.get("kingdomGuard", false) or body.get("kingdomAdd", false):
		_toast(str(body.name).to_lower() + (" is removed from the minutes." if body.get("kingdomAdd", false) else " files an objection from the ground.\nno payment authorized."), 1800)
		return true
	if id == "brutus":
		host.p.brutusDefeated += 1
		if host.p.brutusDefeated >= 5: _wall_queue.append({"kind":"older", "due":_wall_ms + 1500.0})
	var night: bool = host.s.dayTime < 0.25 or host.s.dayTime > 0.75
	var torch_chance: float = 0.375 if host.p.faction.street >= 25 else 0.25
	if id in ["brutus", "brutus_older"] and night and not inventory.owns_tool("propane_torch") and host.random_float() < torch_chance:
		_drop(body, 0, {"tool":"propane_torch"}, "cp_torch")
		_toast("something falls off his collar.\nit smells like a parking lot.", 2400)
	if body.get("isCop", false):
		host.p.cred += 10; host.p.wanted = mini(3, int(host.p.wanted) + 1); host.p.lifetime.copsKilled += 1
		if body.get("isBrendan", false):
			# Approved repair of the source's bare cashPiles ReferenceError.
			_drop(body, 30, {}, "cp_brendan")
			host.unlock_achievement("badge_money")
			if not host.s.counters.get("brendanFirstKill", 0):
				host.s.counters.brendanFirstKill = 1
				_feed("uncle dean is posting on facebook again.", "@local_eyewitness")
				host.emit_event("news", {"text":"LOCAL ROOKIE DOWN. UNCLE DEAN POSTING. FAMILY GROUP CHAT GOES QUIET."})
			else: _feed("brendan again. the family is going to have words.", "@local_eyewitness")
			_toast("+ 10 cred · wanted +1\ncousin brendan is on the ground.\nhis badge fell out. it is yours now.")
		else: _toast("+ 10 cred · wanted +1\na cop is on the ground.")
		host.apply_rep({"street":-3, "spiritual":1})
	else:
		host.p.cred += 3; _toast("+ 3 cred\n" + str(body.name) + " is on the ground.")
	if id in ["lurch", "sherri", "paulie"]: host.s.counters.alleyKills = int(host.s.counters.get("alleyKills", 0)) + 1
	if id in ["brutus", "brutus_older", "lurch", "sherri", "paulie"]: host.apply_rep({"street":1})
	if id == "dave" and host.s.flags.get("daveHasCrossword", false) and not host.s.flags.get("hasCrossword", false):
		host.s.flags.daveHasCrossword = false; host.s.flags.hasCrossword = true
		inventory.append_item("crossword", "barb's saturday crossword")
		_toast("a folded newspaper falls out of his coat.\n+ saturday crossword", 3000)
	var alley_dead: bool = true
	for alley_id: String in ["lurch", "sherri", "paulie"]:
		if not actor(alley_id).get("dead", false): alley_dead = false
	if alley_dead: host.unlock_achievement("mayor_of_4th")
	if id == "stripe":
		host.s.counters.stripeBetrayed = int(host.s.counters.get("stripeBetrayed", 0)) + 1
		if host.s.counters.get("plateStolen", 0) >= 1: host.unlock_achievement("judas")
	# Compatibility: every ordinary fists kill, not only Larry, yields the pipe.
	if (id == "larry" and not host.p.get("weapon")) or host.p.get("weapon") == "fists": _pickup_weapon("pipe")
	if id == "lurch" and host.random_float() < 0.5: _pickup_weapon("brick")
	if id == "paulie" and host.random_float() < 0.5: _pickup_weapon("baguette")
	if id != "cop" and host.random_float() < 0.5:
		host.p.cash += 2 + host.random_index(5); _toast("+ a few dollars", 1400)
	_save()
	return true


func aggro(id: String) -> bool:
	var body: Dictionary = actor(id)
	if body.is_empty() or body.get("dead", false) or body.get("essential", false): return false
	body.hostile = true; body.aggro = true
	if not body.get("dmg", 0): body.dmg = 8
	host.p.wanted = mini(3, int(host.p.wanted) + 1)
	if body.get("archetype") == "swarmer" and id == "sherri": spawn_swarmer(body)
	return true


func spawn_swarmer(parent: Dictionary) -> Dictionary:
	var live: Array[Dictionary] = []
	for body: Dictionary in host.npcs:
		var id: String = str(body.get("id", ""))
		if body.get("archetype") == "swarmer" and not body.get("dead", false) and (id == "sherri" or id.begins_with("sherri_")): live.append(body)
	if live.size() >= 2: return {}
	for body: Dictionary in live:
		if not is_same(body, parent) and Vector2(body.x, body.y).distance_squared_to(Vector2(parent.x, parent.y)) < 160000.0: return {}
	var sibling: Dictionary = {"id":_id("sherri"), "name":"SPIDER-BITE SHERRI", "sprite":"sherri", "x":float(parent.x) + 60.0, "y":parent.y,
		"w":26, "h":30, "hp":45, "maxHp":45, "speed":2.0, "hostile":true, "aggro":true, "aggroOnHit":true, "dmg":5,
		"wander":true, "archetype":"swarmer", "attackCd":0.0, "showHp":false, "transient":true}
	if not clear_actor(sibling): return {}
	host.npcs.append(sibling)
	host.emit_event("actor_spawned", {"actor_id":sibling.id})
	host.emit_event("toast", {"text":"another one shows up.\nit has the same haircut.", "duration_ms":2400, "delay_ms":200})
	return sibling


func spawn_projectile(spec: Dictionary) -> bool:
	if not _sync_epoch(): return false
	for key: String in ["x", "y", "tx", "ty"]:
		if not finite_number(spec.get(key)): return false
	for key: String in ["speed", "dmg", "slowMs", "wobble"]:
		if spec.has(key) and not finite_number(spec[key]): return false
	var speed: float = float(spec.get("speed", 320.0))
	var damage: float = float(spec.get("dmg", 15.0))
	var slow: float = float(spec.get("slowMs", 0.0))
	var wobble: float = float(spec.get("wobble", 0.0))
	var kind: Variant = spec.get("kind", "bottle")
	if speed <= 0.0 or speed > 10000.0 or damage <= 0.0 or damage > 1000000000.0 or slow < 0.0 or slow > 240000.0 or absf(wobble) > TAU or kind not in ["bottle", "holy"]: return false
	var direction := Vector2(float(spec.tx) - float(spec.x), float(spec.ty) - float(spec.y))
	var angle: float = direction.angle()
	if wobble != 0.0: angle += (host.random_float() - 0.5) * wobble
	var source: Dictionary = spec.get("from", {}) if spec.get("from", {}) is Dictionary else {}
	host.projectiles.append({"x":float(spec.x), "y":float(spec.y), "vx":cos(angle) * speed, "vy":sin(angle) * speed,
		"dmg":damage, "slowMs":slow, "kind":kind, "from":source, "rot":angle, "rotVel":0.05 if kind == "holy" else 0.25, "life":4000.0})
	if host.projectiles.size() > 40: host.projectiles.pop_front()
	return true


static func segment_rect_fraction(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var delta := end - start
	var enter: float = 0.0
	var leave: float = 1.0
	for axis: int in range(2):
		if absf(delta[axis]) < 0.0000001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]: return INF
		else:
			var a: float = (rect.position[axis] - start[axis]) / delta[axis]
			var b: float = (rect.end[axis] - start[axis]) / delta[axis]
			enter = maxf(enter, minf(a, b)); leave = minf(leave, maxf(a, b))
			if enter > leave: return INF
	return enter


func tick_projectiles(dt_ms: float) -> bool:
	if not _sync_epoch() or not valid_step(dt_ms) or not has_physics(&"sweep_projectile"): return false
	var bounds: Dictionary = host.content.world.bounds
	for index: int in range(host.projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = host.projectiles[index]
		var start := Vector2(projectile.x, projectile.y)
		var end := start + Vector2(projectile.vx, projectile.vy) * (dt_ms / 1000.0)
		var collision: Variant = _physics().call(&"sweep_projectile", start, end, 0.5)
		if not collision is Dictionary or not collision.get("blocked") is bool or not finite_number(collision.get("fraction")) or float(collision.fraction) < 0.0 or float(collision.fraction) > 1.0 or not collision.get("position") is Vector2 or not collision.position.is_finite():
			# A broken geometry contract cannot tunnel or damage. Discard this unsafe shot.
			host.projectiles.remove_at(index)
			dependency_missing("invalid_projectile_sweep")
			continue
		projectile.life -= dt_ms
		projectile.rot += float(projectile.rotVel) * dt_ms / (1000.0 / 60.0)
		var wall_fraction: float = float(collision.fraction) if collision.blocked else INF
		var player_rect := Rect2(Vector2(host.p.x, host.p.y) - Vector2(4, 4), Vector2(host.p.w, host.p.h) + Vector2(8, 8))
		var player_fraction: float = segment_rect_fraction(start, end, player_rect)
		var dead: bool = false
		if is_finite(player_fraction) and player_fraction < wall_fraction:
			var impact := start.lerp(end, player_fraction)
			projectile.x = impact.x; projectile.y = impact.y
			_hurt_player(float(projectile.dmg), projectile.from)
			if projectile.slowMs > 0: host.p.slowT = maxf(float(host.p.slowT), float(projectile.slowMs))
			_sound("bottleHit" if projectile.kind == "bottle" else "holyWaterHit")
			host.emit_event("projectile_impact", {"position":impact, "kind":projectile.kind, "player":true})
			dead = true
		elif collision.blocked:
			host.emit_event("projectile_impact", {"position":collision.position, "kind":projectile.kind, "player":false})
			dead = true
		else:
			projectile.x = end.x; projectile.y = end.y
			dead = end.x < 0.0 or end.y < 0.0 or end.x > float(bounds.w) or end.y > float(bounds.h)
		if not dead and projectile.life <= 0:
			if projectile.kind == "bottle": _sound("bottleHit")
			dead = true
		if dead: host.projectiles.remove_at(index)
	return true


func _live_cops() -> Array[Dictionary]:
	var cops: Array[Dictionary] = []
	for body: Dictionary in host.npcs:
		if body.get("isCop", false) and not body.get("dead", false): cops.append(body)
	return cops


func _spawn_cop(at_edge: bool, brendan: bool = false) -> Dictionary:
	if _live_cops().size() >= COP_CAP: return {}
	var bounds: Dictionary = host.content.world.bounds
	var point: Vector2 = host.player_center()
	var x: float; var y: float
	if at_edge:
		var nearest: float = minf(minf(point.x, float(bounds.w) - point.x), minf(point.y, float(bounds.h) - point.y))
		var jitter: float = (host.random_float() - 0.5) * 300.0
		if nearest == point.x: x = 30.0; y = clampf(point.y + jitter, 40.0, float(bounds.h) - 40.0)
		elif nearest == float(bounds.w) - point.x: x = float(bounds.w) - 30.0; y = clampf(point.y + jitter, 40.0, float(bounds.h) - 40.0)
		elif nearest == point.y: y = 30.0; x = clampf(point.x + jitter, 40.0, float(bounds.w) - 40.0)
		else: y = float(bounds.h) - 30.0; x = clampf(point.x + jitter, 40.0, float(bounds.w) - 40.0)
	else:
		x = clampf(float(host.p.x) + (-400.0 if host.random_float() < 0.5 else 400.0), 40.0, float(bounds.w) - 40.0)
		y = clampf(float(host.p.y) + (-300.0 if host.random_float() < 0.5 else 300.0), 40.0, float(bounds.h) - 40.0)
	var cop: Dictionary = {"id":_id("brendan" if brendan else "cop"), "name":"COUSIN BRENDAN" if brendan else "COP", "sprite":"brendan" if brendan else "cop",
		"x":x, "y":y, "w":26 if brendan else 28, "h":30 if brendan else 32, "hp":55 if brendan else 60, "maxHp":55 if brendan else 60,
		"speed":2.3 if brendan else 1.5, "dmg":50 if brendan else 10, "hostile":true, "aggro":true, "isCop":true, "isBrendan":brendan,
		"attackCd":0.0, "wanderT":0.0, "targetX":0.0, "targetY":0.0, "showHp":true, "archetype":"brendan" if brendan else "cop", "transient":true}
	if brendan: cop.taserChargeT = 0.0
	if not clear_actor(cop): return {}
	host.npcs.append(cop)
	host.emit_event("actor_spawned", {"actor_id":cop.id})
	if at_edge: _sound("copSiren")
	return cop


func tick_police(dt_ms: float, wall_ms: float) -> bool:
	if not _sync_epoch() or not valid_step(dt_ms) or not is_finite(wall_ms) or wall_ms < _wall_ms: return false
	_wall_ms = wall_ms
	if host.p.wanted <= 0: host.p.wantedT = 0.0; return true
	host.p.wantedT += dt_ms * float(host.p.get("wantedDecayMult", 1.0))
	if host.p.wantedT >= 18000.0:
		host.p.wantedT = 0.0; host.p.wanted -= 1
		if host.p.wanted == 0: _toast("the heat dies down.\nfor now.", 1500)
	var cops: Array[Dictionary] = _live_cops()
	if cops.size() < int(host.p.wanted) and cops.size() < COP_CAP:
		var live_brendan: bool = false
		for body: Dictionary in cops:
			if body.get("isBrendan", false): live_brendan = true
		var brendan: bool = host.p.wanted >= 2 and not live_brendan and host.random_float() < 0.3
		_sound("copSiren")
		var spawned: Dictionary = _spawn_cop(false, brendan)
		if brendan and not spawned.is_empty():
			_wall_queue.append({"kind":"brendan_line", "due":_wall_ms + 500.0})
	for cop: Dictionary in _live_cops():
		if cop.get("isBrendan", false): continue
		if center(cop).distance_squared_to(host.player_center()) < 14400.0: cop.radioT = 0.0; continue
		cop.radioCdT = float(cop.get("radioCdT", 0.0)) - dt_ms
		cop.radioT = float(cop.get("radioT", 0.0)) + dt_ms
		if cop.radioCdT <= 0.0 and host.random_float() < 0.25 * dt_ms / 1000.0:
			cop.radioCdT = 5000.0; cop.radioVisualT = 800.0
			_sound("radio")
			_wall_queue.append({"kind":"radio", "caller":str(cop.id), "due":_wall_ms + 800.0 + host.random_float() * 4000.0})
		if cop.get("radioVisualT", 0.0) > 0.0: cop.radioVisualT = maxf(0.0, float(cop.radioVisualT) - dt_ms)
	return true


func tick_wall(wall_ms: float) -> bool:
	if not _sync_epoch() or not is_finite(wall_ms) or wall_ms < _wall_ms: return false
	_wall_ms = wall_ms
	var pending: Array[Dictionary] = []
	for task: Dictionary in _wall_queue:
		if float(task.due) > wall_ms: pending.append(task); continue
		match task.kind:
			"radio":
				var caller: Dictionary = actor(task.caller)
				if caller.is_empty() or caller.get("dead", false) or host.p.wanted <= 0: continue
				_spawn_cop(true)
				if _live_cops().size() <= COP_CAP: _toast("more flashing lights.\nfrom somewhere.", 1800)
			"brendan_line":
				var lines: Array[String] = ["stop! it's me!! it's brendan!!", "uncle dean said don't make him come down here!!"]
				_toast("· COUSIN BRENDAN ARRIVES ·\n" + lines[host.random_index(lines.size())], 3200)
			"older":
				if domain_has(&"spawn_brutus_older"): domain_call(&"spawn_brutus_older")
				else: dependency_missing("spawn_brutus_older")
	_wall_queue = pending
	return true
