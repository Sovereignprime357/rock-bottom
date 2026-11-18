class_name SliceSimulation
extends RefCounted
## One owner for the first playable's resources, clocks and bounded transactions.
## Scene code owns spatial legality and pauses by not calling tick().

const SAVE_SCHEMA: int = 1
const DAY_SECONDS: float = 240.0
const HIGH_SECONDS: float = 18.0
const CRASH_SECONDS: float = 8.0
const PETE_DAILY_CAP: int = 200
const RESOURCE_LIMIT: int = 999999
const SPAWN: Vector3 = Vector3(0.0, 0.0, 8.0)
const CASH_FINDS: Dictionary = {"cash_1": 5, "cash_2": 4, "cash_3": 3}
const DUMPSTERS: Array[String] = ["dumpster_1", "dumpster_2", "dumpster_3"]
const COLLECTIBLE_IDS: Array[String] = [
	"cash_1", "cash_2", "cash_3", "copper_1", "dumpster_1", "dumpster_2", "dumpster_3",
]

var hp: float = 100.0
var cash: int = 0
var rocks: int = 0
var shakes: float = 20.0
var brain: float = 100.0
var cred: int = 0
var junk: int = 0
var copper: int = 0
var food: int = 0
var day: int = 1
var day_time: float = 0.0
var high_remaining: float = 0.0
var crash_remaining: float = 0.0
var pete_paid: int = 0
var collected: Dictionary = {}
var defeated: Dictionary = {}


func fresh() -> void:
	hp = 100.0
	cash = 0
	rocks = 0
	shakes = 20.0
	brain = 100.0
	cred = 0
	junk = 0
	copper = 0
	food = 0
	day = 1
	day_time = 0.0
	high_remaining = 0.0
	crash_remaining = 0.0
	pete_paid = 0
	collected.clear()
	defeated.clear()


func tick(dt: float, moving_sprint: bool = false, at_block: bool = false) -> Array[String]:
	var events: Array[String] = []
	if not is_finite(dt) or dt <= 0.0:
		return events
	# Consume each interval only once. A frame crossing 18s spends its remainder
	# in the crash; it never shortens the high or grants an extra crash frame.
	var unspent: float = dt
	while unspent > 0.0:
		var was_high: bool = high_remaining > 0.0
		var was_crash: bool = not was_high and crash_remaining > 0.0
		var step: float = unspent
		if was_high:
			step = minf(step, high_remaining)
		elif was_crash:
			step = minf(step, crash_remaining)
		unspent -= step
		if _advance_body(step, moving_sprint, at_block):
			events.append("death")
			break
		if was_high:
			high_remaining = maxf(0.0, high_remaining - step)
			if high_remaining <= 0.000001:
				high_remaining = 0.0
				crash_remaining = CRASH_SECONDS
				shakes = minf(100.0, shakes + 30.0)
				events.append("crash")
		elif was_crash:
			crash_remaining = maxf(0.0, crash_remaining - step)
			if crash_remaining <= 0.000001:
				crash_remaining = 0.0
				events.append("crash_end")

	day_time += dt
	if day_time >= DAY_SECONDS:
		# Constant work even for an oversized delta, rather than a day-by-day loop.
		var days_passed: int = int(minf(floor(day_time / DAY_SECONDS), float(RESOURCE_LIMIT)))
		day = mini(RESOURCE_LIMIT, day + days_passed)
		day_time = fmod(day_time, DAY_SECONDS)
		pete_paid = 0
		collected.clear()
		defeated.clear()
		events.append("day")
	return events


func _advance_body(dt: float, moving_sprint: bool, at_block: bool) -> bool:
	var shake_rate: float = 12.8 if moving_sprint else 0.8
	var before_cap: float = clampf((100.0 - shakes) / shake_rate, 0.0, dt)
	var at_cap: float = dt - before_cap
	shakes = clampf(shakes + dt * shake_rate, 0.0, 100.0)
	# Deterministic equivalent to the legacy 60Hz expected withdrawal rate.
	# Integrate only time actually spent at 100, including a mid-frame crossing.
	if at_block:
		hp = minf(100.0, hp + before_cap * 6.0 + at_cap * (6.0 - 0.72))
		return false
	return hurt(at_cap * 0.72) if at_cap > 0.0 else false


func speed_multiplier() -> float:
	if high_remaining > 0.0:
		return 1.8
	if crash_remaining > 0.0:
		return 0.5
	return 1.0


func damage() -> float:
	return 27.0 if high_remaining > 0.0 else 18.0


func transact(action: String, target: String = "") -> Dictionary:
	match action:
		"buy_rock":
			if cash < 10:
				return _result(false, "come back with money.")
			if rocks >= RESOURCE_LIMIT:
				return _result(false, "the pockets are full.")
			cash -= 10
			rocks += 1
			return _result(true, "- $10\n+ 1 rock", "coin")
		"smoke":
			if target != "" and target != "block":
				return _result(false, "the crate is elsewhere.")
			if high_remaining > 0.0:
				return _result(false, "the sun is already moving.")
			if rocks <= 0:
				return _result(false, "you have no rocks.")
			rocks -= 1
			shakes = maxf(0.0, shakes - 50.0)
			brain = maxf(0.0, brain - 4.0)
			cred = mini(RESOURCE_LIMIT, cred + 1)
			high_remaining = HIGH_SECONDS
			crash_remaining = 0.0
			return _result(true, "the sun moves.\nbrain -4. shakes -50.", "high")
		"pawn_sock":
			if pete_paid >= PETE_DAILY_CAP:
				return _pete_empty()
			pete_paid += 1
			cash = mini(RESOURCE_LIMIT, cash + 1)
			return _result(true, "+ $1\n(it is wet.)", "coin")
		"sell_junk":
			if junk <= 0:
				return _result(false, "you have no junk. pete keeps eating.")
			var junk_paid: int = mini(junk, PETE_DAILY_CAP - pete_paid)
			if junk_paid <= 0:
				return _pete_empty()
			junk -= junk_paid
			pete_paid += junk_paid
			cash = mini(RESOURCE_LIMIT, cash + junk_paid)
			return _result(true, "- %d junk\n+ $%d\npete weighs each piece." % [junk_paid, junk_paid], "coin")
		"sell_copper_pete":
			if copper <= 0:
				return _result(false, "you have no pure copper.")
			var copper_paid: int = mini(15, PETE_DAILY_CAP - pete_paid)
			if copper_paid <= 0:
				return _pete_empty()
			copper -= 1
			pete_paid += copper_paid
			cash = mini(RESOURCE_LIMIT, cash + copper_paid)
			return _result(true, "pete weighs it for 11 minutes.\n- 1 pure copper\n+ $%d" % copper_paid, "coin")
		"sell_copper_yuri":
			if copper <= 0:
				return _result(false, "what you bring, idiot.")
			copper -= 1
			cash = mini(RESOURCE_LIMIT, cash + 25)
			return _result(true, "- 1 pure copper\n+ $25\nyuri does not look up.", "coin")
		"buy_food":
			if cash < 3:
				return _result(false, "food is $3.")
			if food >= RESOURCE_LIMIT:
				return _result(false, "the pockets are full.")
			cash -= 3
			food += 1
			return _result(true, "- $3\n+ a can of food (unmarked).", "coin")
		"eat_food":
			if food <= 0:
				return _result(false, "the can is elsewhere.")
			if hp >= 100.0:
				return _result(false, "you are full. the can waits.")
			food -= 1
			hp = minf(100.0, hp + 15.0)
			return _result(true, "- 1 food\n+ 15 hp\n(the label explains nothing.)", "pickup")
		"collect_cash":
			if not CASH_FINDS.has(target):
				return _result(false, "there is nothing there.")
			if collected.has(target):
				return _result(false, "the ground has already paid.")
			var found_cash: int = int(CASH_FINDS[target])
			collected[target] = true
			cash = mini(RESOURCE_LIMIT, cash + found_cash)
			return _result(true, "+ $%d\n(the pavement had it.)" % found_cash, "pickup")
		"collect_copper":
			if target != "copper_1":
				return _result(false, "there is nothing there.")
			if collected.has(target):
				return _result(false, "the copper is gone. b flat remains.")
			collected[target] = true
			copper = mini(RESOURCE_LIMIT, copper + 1)
			return _result(true, "+ 1 pure copper\nit sings in b flat.", "pickup")
		"dumpster_cash", "dumpster_junk", "dumpster_food":
			if not DUMPSTERS.has(target):
				return _result(false, "there is no dumpster there.")
			if collected.has(target):
				return _result(false, "the dumpster is empty.\nyou look anyway.")
			collected[target] = true
			if action == "dumpster_cash":
				cash = mini(RESOURCE_LIMIT, cash + 6)
				return _result(true, "+ $6\n(the envelope says rent.)", "pickup")
			if action == "dumpster_junk":
				junk = mini(RESOURCE_LIMIT, junk + 3)
				return _result(true, "+ 3 junk\none has a warranty.", "pickup")
			food = mini(RESOURCE_LIMIT, food + 1)
			return _result(true, "+ a can of food\nthe can is unmarked.", "pickup")
		"defeat_lurch":
			if defeated.has("lurch"):
				return _result(false, "lurch is still on the ground.")
			defeated["lurch"] = true
			cred = mini(RESOURCE_LIMIT, cred + 3)
			return _result(true, "+ 3 cred\nlurch is on the ground.", "pickup")
	return _result(false, "nothing changes.")


func hurt(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	if hp > 0.0:
		return false
	hp = 60.0
	shakes = 30.0
	cred = maxi(0, cred - 10)
	high_remaining = 0.0
	crash_remaining = 0.0
	return true


func snapshot(position: Vector3, yaw: float) -> Dictionary:
	return {
		"schema": SAVE_SCHEMA,
		"hp": hp, "cash": cash, "rocks": rocks, "shakes": shakes, "brain": brain,
		"cred": cred, "junk": junk, "copper": copper, "food": food,
		"day": day, "day_time": day_time, "pete_paid": pete_paid,
		"collected": collected.duplicate(true), "defeated": defeated.duplicate(true),
		"position": [position.x, position.y, position.z], "yaw": yaw,
	}


func restore(data: Dictionary) -> Dictionary:
	fresh()
	var placement: Dictionary = {"position": SPAWN, "yaw": 0.0}
	if _number(data.get("schema"), -1.0) != float(SAVE_SCHEMA):
		return placement
	hp = _bounded(data.get("hp"), 100.0, 0.0, 100.0)
	if hp <= 0.0:
		hp = 60.0
	cash = _natural(data.get("cash"))
	rocks = _natural(data.get("rocks"))
	shakes = _bounded(data.get("shakes"), 20.0, 0.0, 100.0)
	brain = _bounded(data.get("brain"), 100.0, 0.0, 100.0)
	cred = _natural(data.get("cred"))
	junk = _natural(data.get("junk"))
	copper = _natural(data.get("copper"))
	food = _natural(data.get("food"))
	day = maxi(1, _natural(data.get("day")))
	day_time = _bounded(data.get("day_time"), 0.0, 0.0, DAY_SECONDS - 0.000001)
	pete_paid = mini(PETE_DAILY_CAP, _natural(data.get("pete_paid")))
	var saved_collected: Variant = data.get("collected", {})
	if saved_collected is Dictionary:
		for key: String in COLLECTIBLE_IDS:
			if saved_collected.get(key) is bool and saved_collected.get(key) == true:
				collected[key] = true
	var saved_defeated: Variant = data.get("defeated", {})
	if saved_defeated is Dictionary and saved_defeated.get("lurch") is bool and saved_defeated.get("lurch") == true:
		defeated["lurch"] = true
	var saved_position: Variant = data.get("position")
	if saved_position is Array and saved_position.size() == 3:
		if _is_number(saved_position[0]) and _is_number(saved_position[1]) and _is_number(saved_position[2]):
			placement["position"] = Vector3(
				clampf(float(saved_position[0]), -40.0, 40.0),
				0.0,
				clampf(float(saved_position[2]), -36.0, 28.0)
			)
	placement["yaw"] = wrapf(_number(data.get("yaw"), 0.0), -PI, PI)
	# Fresh v22 loads reset transient high/crash timers. Keep that deliberate
	# behavior; caller also closes modal state and resolves geometry overlap.
	return placement


func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _number(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback


func _bounded(value: Variant, fallback: float, low: float, high: float) -> float:
	return clampf(_number(value, fallback), low, high)


func _natural(value: Variant) -> int:
	return int(_bounded(value, 0.0, 0.0, float(RESOURCE_LIMIT)))


func _pete_empty() -> Dictionary:
	return _result(false, "pete is empty. pete is eating.\ncome back tomorrow.")


func _result(ok: bool, text: String, event: String = "") -> Dictionary:
	return {"ok": ok, "text": text, "event": event}
