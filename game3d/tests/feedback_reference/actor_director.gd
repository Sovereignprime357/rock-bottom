extends RefCounted
## Model actor motion and decisions. Rendering may consume snapshots but never drive hits.
const Combat = preload("res://tests/feedback_reference/combat_system.gd")
const METRES_PER_PIXEL := 0.04
var _host_ref: WeakRef
var _combat_ref: WeakRef
var _companion_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var combat: RefCounted:
	get: return _combat_ref.get_ref() if _combat_ref != null else null
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _poses: Dictionary = {}
var _departures: Dictionary = {}
var _wall_ms: float = 0.0
var profile_enabled: bool = false
var profile_us: Dictionary = {}


func _init(owner: RefCounted, combat_system: RefCounted) -> void:
	_host_ref = weakref(owner); _combat_ref = weakref(combat_system)
	_sync_epoch()

func set_companion_owner(owner: RefCounted) -> void:
	_companion_ref = weakref(owner) if owner != null else null
func reset_actor(id: String) -> void:
	_poses.erase(id); _departures.erase(id)
func tick_dog_discomfort() -> bool:
	if not _sync_epoch(): return false
	_dog_discomfort(); return true


func _sync_epoch() -> bool:
	if host == null or combat == null: return false
	if not is_same(_player_epoch, host.p) or not is_same(_state_epoch, host.s):
		_player_epoch = host.p; _state_epoch = host.s; _poses.clear(); _departures.clear()
	return true


func supported(body: Dictionary) -> bool:
	if body.get("archetype", "default") not in ["default", "passive", "cop", "brendan", "charger", "charger_older", "grabber", "swarmer", "ranged", "priest_fallen"]: return false
	if body.get("robs", false) and not combat.domain_has(&"attempt_robbery"): return false
	return true


func _position(body: Dictionary) -> Vector2: return Vector2(float(body.x), float(body.y))
func _speed(body: Dictionary, fallback: float) -> float:
	var value: float = float(body.get("speed", 0.0))
	return value if value != 0.0 else fallback
func _damage(body: Dictionary, fallback: float) -> float:
	var value: float = float(body.get("dmg", 0.0))
	return value if value != 0.0 else fallback
func _move(body: Dictionary, delta: Vector2, goal: Variant = null, stop: bool = false) -> Dictionary:
	var profile_started: int = Time.get_ticks_usec() if profile_enabled else 0
	var result: Dictionary = combat.move_actor(body, _position(body) + delta, goal, stop)
	if profile_enabled: profile_us.motion = int(profile_us.get("motion",0))+Time.get_ticks_usec()-profile_started
	return result
func _touching(body: Dictionary) -> bool:
	return not body.get("essential", false) and Combat.overlaps(host.p, body) and combat.can_hit(Combat.center(body), host.player_center(), str(body.id), "player")
func _hit(body: Dictionary, amount: float, cooldown: float) -> void:
	combat.damage_player(amount, body); body.attackCd = cooldown


func tick(dt_ms: float, wall_ms: float) -> bool:
	if not _sync_epoch() or not Combat.valid_step(dt_ms) or not is_finite(wall_ms) or wall_ms < _wall_ms: return false
	if not combat.has_physics(&"move_body") or not combat.has_physics(&"clear_placement") or not combat.has_physics(&"can_hit"): return false
	_wall_ms = wall_ms
	# Full Runtime calls the aura before clocks/companion returns, matching updateWorld.
	# Standalone Director clients retain their prior ordering until a lifecycle owner is bound.
	if _companion_ref == null or _companion_ref.get_ref() == null: _dog_discomfort()
	for body: Dictionary in host.npcs.duplicate():
		var start := _position(body)
		var old_cd: float = float(body.get("attackCd", 0.0))
		if body.get("dead", false): _record(body, start, dt_ms, old_cd); continue
		if not supported(body):
			combat.dependency_missing("actor:" + str(body.id)); _record(body, start, dt_ms, old_cd); continue
		var profile_started: int = Time.get_ticks_usec() if profile_enabled else 0
		var cleared: bool = combat.clear_actor(body)
		if profile_enabled: profile_us.clearance = int(profile_us.get("clearance",0))+Time.get_ticks_usec()-profile_started
		if not cleared: continue
		body.attackCd = maxf(0.0, old_cd - dt_ms)
		body.hitFlash = maxf(0.0, float(body.get("hitFlash", 0.0)) - dt_ms)
		if body.get("hitStun", 0.0) > 0.0:
			body.hitStun = maxf(0.0, float(body.hitStun) - dt_ms)
			_record(body, start, dt_ms, old_cd); continue
		_chatter(body, dt_ms)
		if body.get("zoneOnly") is Dictionary and not body.get("aggro", false):
			var zone: Dictionary = body.zoneOnly
			var point: Vector2 = host.player_center()
			body.hostile = point.x >= zone.x and point.x <= zone.x + zone.w and point.y >= zone.y and point.y <= zone.y + zone.h
		if body.get("isPet", false): _pet(body, dt_ms)
		if body.get("isAlly", false): _ally(body, dt_ms)
		elif body.get("aggro", false) or (body.get("hostile", false) and Combat.center(body).distance_squared_to(host.player_center()) < 129600.0):
			_hostile(body, dt_ms)
		else:
			if _passive(body, dt_ms): continue
		if (body.get("kingdomGuard", false) or body.get("kingdomPretender", false) or body.get("kingdomBoss", false) or body.get("kingdomAdd", false)) and body.get("zoneOnly") is Dictionary:
			var zone: Dictionary = body.zoneOnly
			combat.move_actor(body, Vector2(clampf(body.x, zone.x + 6.0, zone.x + zone.w - body.w - 6.0), clampf(body.y, zone.y + 6.0, zone.y + zone.h - body.h - 6.0)))
		if host.p.cartMounted and body.attackCd == 0.0 and (body.get("hostile", false) or body.get("aggro", false)) and not body.get("essential", false) and Combat.overlaps(host.p, body, 4.0) and combat.can_hit(host.player_center(), Combat.center(body), "player", str(body.id)):
			if combat.damage_actor(str(body.id), 14.0):
				body.attackCd = 600.0
				var away := _position(body) - _position(host.p)
				if away.length_squared() == 0.0: away = Vector2.RIGHT
				_move(body, away.normalized() * 10.0)
				host.emit_event("sound", {"id":"hit"})
		_record(body, start, dt_ms, old_cd)
	return true


func _chatter(body: Dictionary, dt: float) -> void:
	if body.get("chatterT", 0.0) > 0.0: body.chatterT -= dt
	body.chatterCd = float(body.get("chatterCd", 0.0)) - dt
	if body.chatterCd <= 0.0 and not body.get("asleep", false) and not body.get("aggro", false):
		body.chatterCd = 7000.0 + host.random_float() * 9000.0
		var chatter: Dictionary = host.content.definitions.get("src/data/props.js", {}).get("CHATTER", {})
		var lines: Array = chatter.get(str(body.id), [])
		if not lines.is_empty() and Combat.center(body).distance_squared_to(host.player_center()) < 144400.0:
			body.chatter = lines[host.random_index(lines.size())]; body.chatterT = 2600.0
			host.emit_event("actor_chatter", {"actor_id":body.id, "text":body.chatter})


func _pet(body: Dictionary, dt: float) -> void:
	var delta := _position(host.p) - _position(body)
	var distance := delta.length()
	if distance > 48.0: _move(body, delta / distance * _speed(body, 1.6) * dt / 16.0, host.player_center())
	elif distance > 0.0 and distance < 24.0: _move(body, -delta / distance * 0.4 * dt / 16.0, host.player_center())
	if body.id != "pet_possum": return
	var companions: Object = _companion_ref.get_ref() if _companion_ref != null else null
	if companions == null or not companions.has_method(&"tick_possum_reveal"):
		combat.dependency_missing("companion_reveal"); return
	companions.tick_possum_reveal(body,dt)


func _ally(body: Dictionary, dt: float) -> void:
	var target: Dictionary = combat.actor(str(body.get("allyTarget", "tony")))
	if not target.is_empty() and not target.get("dead", false):
		var delta := _position(target) - _position(body)
		if delta.length() > 30.0: _move(body, delta.normalized() * _speed(body, 1.4) * dt / 16.0, Combat.center(target))
		elif body.attackCd <= 0.0 and combat.can_hit(Combat.center(body), Combat.center(target), str(body.id), str(target.id)):
			if combat.damage_actor(str(target.id), 10.0): body.attackCd = 700.0
	else:
		var delta := _position(host.p) - _position(body)
		if delta.length() > 80.0: _move(body, delta.normalized() * _speed(body, 1.2) * dt / 16.0, host.player_center())


func _hostile(body: Dictionary, dt: float) -> void:
	var delta: Vector2 = host.player_center() - Combat.center(body)
	var distance: float = delta.length()
	var toward := delta / (distance if distance > 0.0 else 1.0)
	var step: float = dt / 16.0
	match body.get("archetype", "default"):
		"charger", "charger_older": _charger(body, dt, toward, distance)
		"grabber":
			if body.get("speed", 0.0) > 0.0:
				if body.get("grabFreezeT", 0.0) > 0.0: body.grabFreezeT = maxf(0.0, float(body.grabFreezeT) - dt)
				else: _move(body, toward * body.speed * step, host.player_center())
			if _touching(body) and body.attackCd <= 0.0:
				var robbed: bool = false
				if body.get("robs", false):
					var answer: Variant = combat.domain_call(&"attempt_robbery", [body])
					if not answer is bool: combat.dependency_missing("robbery:" + str(body.id)); return
					robbed = answer
				_hit(body, floor(_damage(body, 8.0) * 1.3), 800.0)
				body.grabFreezeT = 200.0; host.p.stunT = maxf(float(host.p.stunT), 500.0)
				if not robbed and not body.get("grabbedOnce", false):
					body.grabbedOnce = true
					host.emit_event("toast", {"text":"GRABBED.\nhis arms are too long.", "duration_ms":1400})
		"swarmer":
			if body.get("speed", 0.0) > 0.0: _move(body, toward * body.speed * 1.4 * step, host.player_center())
			if _touching(body) and body.attackCd <= 0.0: _hit(body, maxf(1.0, floor(_damage(body, 5.0) * 0.6)), 700.0)
		"ranged": _ranged(body, dt, toward, distance)
		"priest_fallen": _fallen_priest(body, dt, toward, distance)
		_:
			var spook: float = 0.5 if body.get("dogSpookSlow", 0) and (body.get("cop", false) or body.id in ["brendan", "horsecop"]) else 1.0
			if body.get("speed", 0.0) > 0.0: _move(body, toward * body.speed * spook * step, host.player_center())
			body.dogSpookSlow = 0
			if body.get("isBrendan", false): body.taserChargeT = minf(4000.0, float(body.get("taserChargeT", 0.0)) + dt)
			if _touching(body) and body.attackCd == 0.0:
				if body.get("isBrendan", false):
					if body.taserChargeT >= 4000.0:
						_hit(body, 50.0, 1000.0); body.taserChargeT = 0.0; host.emit_event("sound", {"id":"copSiren"})
				else: _hit(body, _damage(body, 8.0), 800.0)


func _charger(body: Dictionary, dt: float, toward: Vector2, distance: float) -> void:
	var older: bool = body.get("archetype") == "charger_older"
	var berserk: bool = body.get("berserk", false)
	var windup: float = 400.0 if berserk else (550.0 if older else 800.0)
	var duration: float = 800.0 if berserk else (1400.0 if older else 1000.0)
	var speed: float = 3.0 if berserk else (2.4 if older else 2.0)
	var multiplier: float = 2.0 if berserk else (1.8 if older else 1.5)
	var cooldown: float = 600.0 if berserk else (1700.0 if older else 1400.0)
	if body.get("structureChargeHit", false):
		body.structureChargeHit = false; body.chargeState = "cooldown"; body.chargeT = cooldown; body.chargeCdT = cooldown
	body.chargeState = body.get("chargeState", "idle")
	body.chargeT = float(body.get("chargeT", 0.0)); body.chargeCdT = maxf(0.0, float(body.get("chargeCdT", 0.0)) - dt)
	match body.chargeState:
		"cooldown":
			body.chargeT -= dt
			if body.chargeT <= 0.0: body.chargeState = "idle"; body.chargeT = 0.0
		"windup":
			body.chargeT -= dt
			if fmod(body.chargeT, 90.0) < 45.0: body.hitFlash = maxf(float(body.hitFlash), 40.0)
			if body.chargeT <= 0.0: body.chargeState = "lunge"; body.chargeT = duration; host.emit_event("sound", {"id":"bossRoar"})
		"lunge":
			body.chargeT -= dt
			if body.has("lungeVx"):
				var moved: Dictionary = _move(body, Vector2(body.lungeVx, body.lungeVy) * speed * dt / 16.0, null, true)
				if moved.blocked: body.structureChargeHit = true
			if _touching(body) and body.attackCd <= 0.0:
				_hit(body, floor(_damage(body, 8.0) * multiplier), 600.0)
				body.chargeState = "cooldown"; body.chargeT = cooldown; body.chargeCdT = cooldown; body.chargeLanded = true
			if body.chargeT <= 0.0:
				if not body.get("chargeLanded", false): host.unlock_achievement("dodged_the_lunge")
				body.chargeLanded = false; body.chargeState = "cooldown"; body.chargeT = cooldown; body.chargeCdT = cooldown
		_:
			if body.get("speed", 0.0) > 0.0: _move(body, toward * body.speed * dt / 16.0, host.player_center())
			if distance < 200.0 and body.chargeCdT <= 0.0:
				body.chargeState = "windup"; body.chargeT = windup; body.lungeVx = toward.x; body.lungeVy = toward.y
				host.emit_event("sound", {"id":"windup"})
	if body.chargeState == "idle" and _touching(body) and body.attackCd <= 0.0: _hit(body, _damage(body, 8.0), 800.0)


func _ranged(body: Dictionary, dt: float, toward: Vector2, distance: float) -> void:
	body.panicT = maxf(0.0, float(body.get("panicT", 0.0)) - dt)
	body.throwT = float(body.get("throwT", 0.0)) - dt
	body.throwAimT = maxf(0.0, float(body.get("throwAimT", 0.0)) - dt)
	if distance < 120.0 and body.panicT <= 0.0: body.panicT = 1000.0
	if body.panicT > 0.0:
		if body.get("speed", 0.0) > 0.0: _move(body, toward * body.speed * dt / 16.0, host.player_center())
		if _touching(body) and body.attackCd <= 0.0: _hit(body, _damage(body, 7.0), 800.0)
		return
	var motion := Vector2(-toward.y, toward.x) * sin(_wall_ms / 500.0)
	if distance < 180.0: motion = -toward
	elif distance > 260.0: motion = toward
	_move(body, motion * _speed(body, 1.5) * dt / 16.0, host.player_center())
	if body.throwT <= 0.0 and distance >= 160.0 and distance <= 280.0:
		if body.throwAimT <= 0.0 and not body.get("aimingThrow", false): body.aimingThrow = true; body.throwAimT = 300.0
		elif body.get("aimingThrow", false) and body.throwAimT <= 0.0:
			body.aimingThrow = false; body.throwT = 1500.0
			var origin := Combat.center(body)
			var target: Vector2 = host.player_center()
			combat.spawn_projectile({"x":origin.x,"y":origin.y,"tx":target.x,"ty":target.y,"speed":320.0,"dmg":15.0,"kind":"bottle","from":body,"wobble":0.35})
			host.emit_event("sound", {"id":"bottleThrow"})


func _fallen_priest(body: Dictionary, dt: float, toward: Vector2, distance: float) -> void:
	var phase_two: bool = float(body.hp) / float(body.maxHp) < 0.5
	if phase_two and not body.get("fallenPhase2",false):
		body.fallenPhase2 = true; host.s.shake = 12.0
		host.emit_event("sound", {"id":"bossRoar"})
		host.emit_event("toast", {"text":"the lord is not here.\nthe lord left.\nhe took the bus.","duration_ms":4200})
	if not phase_two:
		var motion := Vector2(-toward.y,toward.x) * sin(_wall_ms/600.0)
		if distance < 180.0: motion = -toward
		elif distance > 280.0: motion = toward
		_move(body,motion*_speed(body,1.6)*dt/16.0,host.player_center())
		body.throwT = float(body.get("throwT",0.0))-dt
		body.throwAimT = maxf(0.0,float(body.get("throwAimT",0.0))-dt)
		if body.throwT <= 0.0 and distance >= 160.0 and distance <= 300.0:
			if body.throwAimT <= 0.0 and not body.get("aimingThrow",false): body.aimingThrow = true; body.throwAimT = 350.0
			elif body.get("aimingThrow",false) and body.throwAimT <= 0.0:
				body.aimingThrow = false; body.throwT = 1200.0
				var origin := Combat.center(body)
				var target: Vector2 = host.player_center()
				combat.spawn_projectile({"x":origin.x,"y":origin.y,"tx":target.x,"ty":target.y,"speed":280.0,"dmg":22.0,"slowMs":1500.0,"kind":"holy","from":body,"wobble":0.18})
				host.emit_event("sound", {"id":"holyWaterThrow"})
		return
	body.chargeState = body.get("chargeState","idle")
	body.chargeT = float(body.get("chargeT",0.0))
	body.chargeCdT = maxf(0.0,float(body.get("chargeCdT",0.0))-dt)
	if body.get("structureChargeHit",false):
		body.structureChargeHit = false; body.chargeState = "cooldown"; body.chargeT = 1200.0; body.chargeCdT = 1200.0
	match body.chargeState:
		"cooldown":
			body.chargeT -= dt
			if body.chargeT <= 0.0: body.chargeState = "idle"
		"windup":
			body.chargeT -= dt
			if fmod(body.chargeT,90.0) < 45.0: body.hitFlash = maxf(float(body.hitFlash),40.0)
			if body.chargeT <= 0.0: body.chargeState = "lunge"; body.chargeT = 900.0
		"lunge":
			body.chargeT -= dt
			if body.has("lungeVx"):
				var moved: Dictionary = _move(body,Vector2(body.lungeVx,body.lungeVy)*2.4*dt/16.0,null,true)
				if moved.blocked: body.structureChargeHit = true
			if _touching(body) and body.attackCd <= 0.0:
				_hit(body,30.0,600.0); host.p.slowT = maxf(float(host.p.slowT),1500.0)
				body.chargeState = "cooldown"; body.chargeT = 1200.0; body.chargeLanded = true
			if body.chargeT <= 0.0:
				if not body.get("chargeLanded",false): host.unlock_achievement("dodged_the_lunge")
				body.chargeLanded = false; body.chargeState = "cooldown"; body.chargeT = 1200.0
		_:
			if body.get("speed",0.0) > 0.0: _move(body,toward*_speed(body,1.6)*dt/16.0,host.player_center())
			if distance < 220.0 and body.chargeCdT <= 0.0:
				body.chargeState = "windup"; body.chargeT = 500.0; body.lungeVx = toward.x; body.lungeVy = toward.y
				host.emit_event("sound", {"id":"windup"})


func _depart(body: Dictionary, dt: float) -> bool:
	if not (body.get("isDay3Visitor",false) or body.get("isPriceGuy",false) or body.get("priceWalkOff",false)):
		combat.dependency_missing("departure_writer:"+str(body.id)); return false
	var bounds: Dictionary = host.content.world.bounds
	var source_target: float = float(body.get("targetX",float(bounds.w)+80.0))
	var edge: String = "west" if source_target < 0.0 else ("east" if source_target > float(bounds.w) else "")
	var exit: Dictionary = combat.resolve_departure(body,edge)
	if exit.is_empty(): combat.dependency_missing("departure_route:"+str(body.id)); return false
	var id: String = str(body.id)
	var progress: Dictionary = _departures.get(id,{})
	if progress.is_empty() or progress.exit_id != exit.exit_id or progress.route != exit.route:
		progress = {"exit_id":exit.exit_id,"route":exit.route.duplicate(),"cursor":0}
		_departures[id] = progress
	var at := Combat.center(body)
	if at.distance_to(exit.target) <= 4.0:
		for index: int in range(host.npcs.size()-1,-1,-1):
			if is_same(host.npcs[index],body): host.npcs.remove_at(index); break
		_poses.erase(str(body.id))
		_departures.erase(id)
		host.emit_event("actor_departed", {"actor_id":body.id,"exit_id":exit.exit_id})
		return true
	var next: Vector2 = exit.target
	while progress.cursor < exit.route.size() and at.distance_to(exit.route[progress.cursor]) <= 4.0: progress.cursor += 1
	if progress.cursor < exit.route.size(): next = exit.route[progress.cursor]
	var delta := next-at
	var distance: float = delta.length()
	if distance > 0.0:
		_move(body,delta/distance*minf(distance,_speed(body,1.2)*dt/16.0),next)
	return false


func _passive(body: Dictionary, dt: float) -> bool:
	var target := _position(body)
	var speed: float = 0.0
	if body.get("patrol") is Array and not body.patrol.is_empty():
		body.patrolT = float(body.get("patrolT", 0.0)) + dt
		var point: Dictionary = body.patrol[int(floor(body.patrolT / 2000.0)) % body.patrol.size()]
		target = Vector2(point.x, point.y); speed = _speed(body, 1.0)
	elif body.get("wanderOff", false):
		return _depart(body,dt)
	elif body.get("wander", false) and body.get("speed", 0.0) > 0.0:
		body.wanderT = float(body.get("wanderT", 0.0)) - dt
		if body.wanderT <= 0.0:
			body.wanderT = 1500.0 + host.random_float() * 2000.0
			body.targetX = body.x + (host.random_float() - 0.5) * 120.0; body.targetY = body.y + (host.random_float() - 0.5) * 120.0
		target = Vector2(body.targetX, body.targetY); speed = float(body.speed) * 0.4
	var delta := target - _position(body)
	if delta.length() > 4.0 and speed > 0.0: _move(body, delta.normalized() * speed * dt / 16.0, target + Vector2(body.w, body.h) * 0.5)
	return false


func _dog_discomfort() -> void:
	var dogs: Array[Dictionary] = []
	if host.s.quests.get("scrap_dog", {}).get("state") == "fed":
		var dog: Dictionary = combat.actor("scrap_dog")
		if not dog.is_empty() and not dog.get("dead", false): dogs.append(dog)
	var follower: Dictionary = combat.actor("freed_dog_follower")
	if not follower.is_empty() and not follower.get("dead", false): dogs.append(follower)
	for body: Dictionary in host.npcs:
		if body.get("dead", false) or (not body.get("cop", false) and body.id not in ["brendan", "horsecop"]): continue
		for dog: Dictionary in dogs:
			if Combat.center(body).distance_squared_to(Combat.center(dog)) < 40000.0: body.dogSpookSlow = 1


func _record(body: Dictionary, start: Vector2, dt: float, old_cd: float) -> void:
	var profile_started: int = Time.get_ticks_usec() if profile_enabled else 0
	var id: String = str(body.id)
	var pose: Dictionary = _poses.get(id, {"yaw":0.0,"action":"","action_serial":0,"death_ms":0.0})
	var movement := _position(body) - start
	var previous_yaw: float = float(pose.yaw)
	if movement.length_squared() > 0.000001: pose.yaw = atan2(movement.x, movement.y)
	var action: String = ""
	var phase: float = 0.0
	var charge: String = str(body.get("chargeState", ""))
	var animal: bool = str(body.get("sprite", body.id)) in ["brutus", "brutus_older", "scrap_dog", "freed_dog", "possum", "pet_possum"]
	var priest: bool = body.get("archetype") == "priest_fallen"
	if charge in ["windup", "lunge", "cooldown"]:
		action = ("lunge" if animal else "strike") if charge == "lunge" else ("windup" if charge == "windup" else "")
		var older: bool = body.get("archetype") == "charger_older"
		var berserk: bool = body.get("berserk", false)
		var duration: float = (400.0 if berserk else (550.0 if older else 800.0)) if charge == "windup" else ((800.0 if berserk else (1400.0 if older else 1000.0)) if charge == "lunge" else (600.0 if berserk else (1700.0 if older else 1400.0)))
		if priest: duration = 500.0 if charge == "windup" else (900.0 if charge == "lunge" else 1200.0)
		phase = clampf(1.0 - float(body.get("chargeT", duration)) / duration, 0.0, 1.0)
	elif body.get("aimingThrow", false) and not (priest and body.get("fallenPhase2",false)):
		action = "throw"
		var aim: float = 350.0 if priest else 300.0
		phase = clampf((1.0-float(body.get("throwAimT",aim))/aim)*0.6,0.0,0.6)
	elif body.get("grabFreezeT", 0.0) > 0.0: action = "grab"; phase = 1.0 - float(body.grabFreezeT) / 200.0
	elif body.get("attackCd", 0.0) > 600.0: action = "bite" if animal else "strike"; phase = clampf(1.0 - (float(body.attackCd) - 600.0) / 400.0, 0.0, 1.0)
	var contact: bool = float(body.get("attackCd", 0.0)) > old_cd
	if contact and action.is_empty(): action = "bite" if animal else "strike"; phase = 0.72
	if action != pose.action or contact: pose.action_serial += 1
	pose.action = action; pose.action_phase = phase; pose.contact = contact
	pose.dead = body.get("dead", false)
	pose.death_ms = float(pose.death_ms) + dt if pose.dead else 0.0
	pose.death_phase = clampf(float(pose.death_ms) / 700.0, 0.0, 1.0)
	pose.source_position = Combat.center(body)
	var world_velocity := Vector3(movement.x, 0.0, movement.y) * METRES_PER_PIXEL * 1000.0 / dt
	pose.local_velocity = world_velocity.rotated(Vector3.UP, -float(pose.yaw))
	pose.turn_rate = angle_difference(previous_yaw, pose.yaw) * 1000.0 / dt
	pose.grounded = true; pose.hurt = clampf(float(body.get("hitFlash", 0.0)) / 200.0, 0.0, 1.0)
	pose.asleep = body.get("asleep",false) == true
	pose.tail_wag = clampf(float(body.get("tailWag",0.0)),0.0,1.0)
	pose.coat_count = clampi(3 - int(body.get("coatsOff", 0)), 0, 3); pose.gaze = Vector2.ZERO
	_poses[id] = pose
	if profile_enabled: profile_us.pose = int(profile_us.get("pose",0))+Time.get_ticks_usec()-profile_started


func snapshot(id: String) -> Dictionary:
	if not _sync_epoch(): return {}
	return _poses.get(id, {}).duplicate(true)
