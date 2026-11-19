extends SceneTree
## Real owner; only the injected spatial capability performs adversarial writes.
const Companions = preload("res://scripts/companion_system.gd")
var checks := 0
var groups := 0
var failures: Array[String] = []

class CountedState:
	extends "res://scripts/game_state.gd"
	var cursor := 0
	func random_float() -> float:
		cursor += 1
		return super.random_float()

class Communications:
	extends RefCounted
	func ready() -> bool: return true
	func post(_text: String,_author: String = "") -> bool: return true
	func broadcast(_text: String) -> bool: return true

class ReentrantSpatial:
	extends RefCounted
	var state_ref: WeakRef
	var owner_ref: WeakRef
	var mode := "none"
	var calls := 0
	var fired := false
	var blocked := false
	var offset := Vector2(8,4)
	var old_pending: Dictionary = {}
	var new_pending: Dictionary = {}
	var old_p: Dictionary = {}
	var old_s: Dictionary = {}
	var selected: Dictionary = {}
	var selected_before: Dictionary = {}
	var after_callback: Dictionary = {}
	var nested_result := false
	var return_point := Vector2.ZERO
	func stage_cash_pickup(point: Vector2,_maximum: float) -> Variant:
		calls += 1
		var state: RefCounted = state_ref.get_ref()
		var owner: RefCounted = owner_ref.get_ref()
		return_point = point+offset
		if not fired and mode != "none":
			fired = true; old_pending = owner._pending_reveal
			old_p = state.p; old_s = state.s
			selected = old_pending.pile; selected_before = selected.duplicate(true)
			match mode:
				"player": state.p = state.p.duplicate(true)
				"state": state.s = state.s.duplicate(true)
				"pending_equal":
					new_pending = old_pending.duplicate(false); owner._pending_reveal = new_pending
				"pending_deep":
					new_pending = old_pending.duplicate(true); owner._pending_reveal = new_pending
				"pending_position": old_pending.position += Vector2(3,1)
				"pending_pile":
					for pile: Dictionary in state.cash_piles:
						if not is_same(pile,selected): old_pending.pile = pile; break
				"pending_clear": old_pending.clear()
				"remove_pile":
					for index: int in range(state.cash_piles.size()):
						if is_same(state.cash_piles[index],selected): state.cash_piles.remove_at(index); break
				"replace_pile":
					for index: int in range(state.cash_piles.size()):
						if is_same(state.cash_piles[index],selected): state.cash_piles[index] = selected.duplicate(true); break
				"collect_pile": selected.collected = true
				"nested_commit":
					# A second real public entry consumes this same request first.
					nested_result = owner.tick_possum_reveal(state.npcs[0],16.0)
			after_callback = snapshot(state)
			after_callback.pending = owner._pending_reveal.duplicate(true)
		return null if blocked else return_point
	static func snapshot(state: RefCounted) -> Dictionary:
		return {"p":state.p.duplicate(true),"s":state.s.duplicate(true),"piles":state.cash_piles.duplicate(true),"events":state.events.duplicate(true),"seed":state.rng_seed,"cursor":state.cursor}

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _rig() -> Dictionary:
	var state := CountedState.new()
	var spatial := ReentrantSpatial.new()
	var comm := Communications.new()
	var owner := Companions.new(state,spatial,comm)
	state.s.mode = "playing"; state.events.clear()
	var pet: Dictionary = {"id":"pet_possum","x":1000.0,"y":850.0,"w":28.0,"h":24.0,"hp":30,"dead":false,"isPet":true,"revealT":0.0}
	state.npcs.assign([pet])
	state.cash_piles.assign([
		{"id":"first","x":1300.0,"y":950.0,"amt":13,"equip":"priest_collar","collected":false},
		{"id":"second","x":1500.0,"y":1150.0,"amt":0,"tool":"propane_torch","collected":false}])
	spatial.state_ref = weakref(state); spatial.owner_ref = weakref(owner)
	return {"state":state,"spatial":spatial,"comm":comm,"owner":owner,"pet":pet}
func _event_count(state: RefCounted,kind: String) -> int:
	var count := 0
	for event: Dictionary in state.events:
		if event.kind == kind: count += 1
	return count
func _receipt(state: RefCounted) -> Dictionary:
	for event: Dictionary in state.events:
		if event.kind == "cash_revealed": return event.payload
	return {}

func _reentrant_cases() -> void:
	for mode: String in ["player","state","pending_equal","pending_deep","pending_position","pending_pile","pending_clear","remove_pile","replace_pile","collect_pile"]:
		var rig: Dictionary = _rig(); rig.spatial.mode = mode
		var before_p: Dictionary = rig.state.p.duplicate(true); var before_s: Dictionary = rig.state.s.duplicate(true)
		var draws: int = rig.state.cursor
		_check(not rig.owner.tick_possum_reveal(rig.pet,16.0),mode+": stale spatial return refused")
		_check(rig.spatial.calls == 1 and rig.spatial.fired,mode+": real capability invoked once")
		_check(rig.state.cursor == draws+4,mode+": only originalfour source draws")
		# Compare without the deliberately separately stored pending witness.
		var observed: Dictionary = ReentrantSpatial.snapshot(rig.state)
		var expected: Dictionary = rig.spatial.after_callback.duplicate(true); expected.erase("pending")
		_check(observed == expected,mode+": p/s/piles/events/seed remain at returned adapter state")
		_check(rig.spatial.old_p == before_p and rig.spatial.old_s == before_s,mode+": old epoch resource values untouched")
		_check(rig.spatial.selected.x == rig.spatial.selected_before.x and rig.spatial.selected.y == rig.spatial.selected_before.y,mode+": old pile never moved by stale return")
		_check(_event_count(rig.state,"cash_revealed") == 0 and _event_count(rig.state,"toast") == 0 and _event_count(rig.state,"save_requested") == 0,mode+": no stale receipt/toast/save/feedback")
		if mode in ["pending_equal","pending_deep"]:
			_check(not is_same(rig.spatial.old_pending,rig.spatial.new_pending) and rig.spatial.old_pending == rig.spatial.new_pending,mode+": equal values are distinct transactions")
			_check(is_same(rig.owner._pending_reveal,rig.spatial.new_pending) and not rig.owner._pending_reveal.is_empty(),mode+": newer pending survives")
		elif mode in ["remove_pile","replace_pile","collect_pile"]:
			_check(rig.owner._pending_reveal.is_empty(),mode+": invalidated current pile request canceled")
		else:
			_check(rig.owner._pending_reveal == rig.spatial.after_callback.pending,mode+": no newer/in-place pending mutation erased")
		groups += 1

func _normal_and_retry() -> void:
	for use_offset: bool in [false,true]:
		var rig: Dictionary = _rig(); rig.spatial.offset = Vector2(8,4) if use_offset else Vector2.ZERO
		var before_p: Dictionary = rig.state.p.duplicate(true); var before_s: Dictionary = rig.state.s.duplicate(true)
		rig.spatial.blocked = true
		_check(not rig.owner.tick_possum_reveal(rig.pet,16.0),"normal blocked intent authored")
		var pending: Dictionary = rig.owner._pending_reveal
		var pile: Dictionary = pending.pile; var pile_before: Dictionary = pile.duplicate(true)
		var point: Vector2 = pending.position+rig.spatial.offset
		var timer: float = rig.pet.revealT; var draws: int = rig.state.cursor; var seed: int = rig.state.rng_seed
		_check(draws == 4 and not pending.is_empty(),"one originalfour-draw selection")
		for index: int in range(3): _check(not rig.owner.tick_possum_reveal(rig.pet,16.0),"blocked retry refuses")
		_check(rig.state.cursor == draws and rig.state.rng_seed == seed and rig.pet.revealT == timer and is_same(rig.owner._pending_reveal,pending),"blocked retries preserve RNG/timer/intent identity")
		rig.spatial.blocked = false
		_check(rig.owner.tick_possum_reveal(rig.pet,16.0),"legitimate unchanged transaction accepts")
		_check(Vector2(pile.x,pile.y) == point and rig.owner._pending_reveal.is_empty(),"actual acceptedpoint commits once")
		var expected: Dictionary = pile_before.duplicate(true); expected.x = point.x; expected.y = point.y
		_check(pile == expected and rig.state.p == before_p and rig.state.s == before_s,"only selected pile coordinates change")
		_check(rig.state.cursor == draws and rig.state.rng_seed == seed and rig.pet.revealT == timer,"acceptance adds no draw or timer advance")
		_check(_event_count(rig.state,"cash_revealed") == 1 and _event_count(rig.state,"toast") == 1 and _event_count(rig.state,"save_requested") == 0,"one source reveal/toast and no invented save")
		var receipt: Dictionary = _receipt(rig.state)
		_check(receipt.get("pile_id") == pile.id and receipt.get("feedback",[]) == [{"recipe":"possum_reveal","source_point":point,"anchor_kind":"ground"}],"successful feedback keeps exact acceptedpoint")
		_check(rig.owner.tick_possum_reveal(rig.pet,16.0) and rig.pet.revealT == timer-16.0 and rig.state.cursor == draws and _event_count(rig.state,"cash_revealed") == 1,"ordinary subsequentturn does not duplicate")
		pile.x += 99.0
		_check(receipt.feedback[0].source_point == point,"feedback remains detached afterlatermove")
		groups += 1

func _newer_request() -> void:
	var rig: Dictionary = _rig(); rig.spatial.mode = "pending_equal"
	_check(not rig.owner.tick_possum_reveal(rig.pet,16.0),"newer equalrequest refuses oldreturn")
	var pending: Dictionary = rig.owner._pending_reveal; var pile: Dictionary = pending.pile
	var expected: Vector2 = pending.position+rig.spatial.offset
	var draws: int = rig.state.cursor; rig.spatial.mode = "none"
	_check(rig.owner.tick_possum_reveal(rig.pet,16.0),"newerrequest cancommit onitsownturn")
	_check(Vector2(pile.x,pile.y) == expected and rig.state.cursor == draws and _event_count(rig.state,"cash_revealed") == 1,"newerrequest commits exactlyonce without reroll")
	groups += 1

func _nested_commit() -> void:
	var rig: Dictionary = _rig(); rig.spatial.mode = "nested_commit"
	_check(not rig.owner.tick_possum_reveal(rig.pet,16.0),"outer stale result refuses afterreal nestedcommit")
	_check(rig.spatial.nested_result and rig.spatial.calls == 2,"real inner ownerentry accepted exactlyonce")
	_check(rig.state.cursor == 4 and rig.owner._pending_reveal.is_empty(),"nestedcommit uses samefour draws")
	var expected: Dictionary = rig.spatial.after_callback.duplicate(true); expected.erase("pending")
	_check(ReentrantSpatial.snapshot(rig.state) == expected,"outerreturn doesnotrewrite innerresult")
	_check(_event_count(rig.state,"cash_revealed") == 1 and _event_count(rig.state,"toast") == 1 and _event_count(rig.state,"save_requested") == 0,"nestedcommit keeps single receipt/feedback/toast")
	groups += 1

func _run() -> void:
	_reentrant_cases(); _normal_and_retry(); _newer_request(); _nested_commit()
	_check(groups == 14,"all14 reentrant/normal groups completed without script abort")
	print("DRAFT COMPANION REVEAL EPOCH: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",groups," groups")
	quit(0 if failures.is_empty() else 1)
