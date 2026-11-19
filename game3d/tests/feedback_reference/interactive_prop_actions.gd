extends RefCounted
## Shared interactiveProps commands. Combat owns swings; Runtime owns active time.
const Inventory = preload("res://scripts/inventory.gd")
const PropState = preload("res://scripts/prop_state.gd")
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _props_ref: WeakRef
var _combat_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var inventory: RefCounted
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _placed: Dictionary = {}
var _pending: Dictionary = {}

func _init(owner: RefCounted,spatial: Object,props: RefCounted,combat: RefCounted = null) -> void:
	_host_ref = weakref(owner); _spatial_ref = weakref(spatial) if spatial != null else null
	_props_ref = weakref(props) if props != null else null
	inventory = Inventory.new(owner)
	if combat != null and combat.has_method(&"set_prop_attack_owner"): combat.set_prop_attack_owner(self)
	reset_session("cold")
func _object(reference: WeakRef,method: StringName) -> Object:
	var value: Object = reference.get_ref() if reference != null else null
	return value if value != null and value.has_method(method) else null
func _same_epoch() -> bool:
	return host != null and is_same(_player_epoch,host.p) and is_same(_state_epoch,host.s)
func ready() -> bool:
	var props: Object = _object(_props_ref,&"interactive_ready")
	var spatial: Object = _object(_spatial_ref,&"stage_interactive_prop")
	return _same_epoch() and props != null and props.interactive_ready() == true and spatial != null and spatial.has_method(&"can_reach_target")
func bind_combat(combat: Object) -> void:
	_combat_ref = weakref(combat) if combat != null and combat.has_method(&"consume_prop_swing") else null
func _record(id: String) -> Dictionary:
	var props: Object = _object(_props_ref,&"interactive_record")
	return props.interactive_record(id) if props != null else {}
func supports(id: String) -> bool: return not _record(id).is_empty()
func _fail(reason: String) -> Dictionary: return {"ok":false,"reason":reason}
func _changed(id: String) -> void: host.emit_event("interactive_prop_changed",{"id":id})
func _toast(text: String,ms: int = 2200) -> void: host.emit_event("toast",{"text":text,"duration_ms":ms})
func _sound(id: String) -> void: host.emit_event("sound",{"id":id})

func reset_session(reason: String) -> bool:
	if host == null or reason not in ["cold","fresh","restore"]: return false
	var props: Object = _object(_props_ref,&"reset_interactive")
	if not _same_epoch():
		var spatial: Object = _object(_spatial_ref,&"begin_interactive_epoch")
		if spatial != null and spatial.begin_interactive_epoch() != true: return false
	if props == null or props.reset_interactive(reason) != true: return false
	if _same_epoch(): return ready()
	_player_epoch = host.p; _state_epoch = host.s
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	_placed.clear(); _pending.clear()
	for index: int in range(14):
		var id := "interactive:%d" % index
		var row: Dictionary = _record(id)
		_pending[id] = {"point":Vector2(row.x,row.y),"respawn":false,"retry_ms":250.0}
		_stage(id)
		if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return false
	if _same_epoch(): host.emit_event("interactive_props_reset",{"reason":reason})
	return ready()

func _stage(id: String) -> bool:
	if not _same_epoch() or not _pending.has(id): return false
	var row: Dictionary = _record(id)
	var spatial: Object = _object(_spatial_ref,&"stage_interactive_prop")
	if row.is_empty() or spatial == null: return false
	var pending: Dictionary = _pending[id]
	var desired: Vector2 = pending.point
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	var proposed: Variant = spatial.call(&"stage_interactive_prop",id,str(row.type),desired,100.0)
	if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s) or not is_same(_pending.get(id),pending): return false
	var bounds: Dictionary = host.content.world.bounds
	if not proposed is Vector2 or not proposed.is_finite() or proposed.distance_to(desired) > 100.0001 or proposed.x < 0 or proposed.y < 0 or proposed.x > bounds.w or proposed.y > bounds.h: return false
	row.x = proposed.x; row.y = proposed.y
	if pending.respawn: row.broken = false
	_pending.erase(id); _placed[id] = true; _changed(id)
	return true

func kick(id: String) -> Dictionary:
	if not ready(): return _fail("missing_dependency")
	var row: Dictionary = _record(id)
	if row.get("type") != "trashcan": return _fail("unknown_trashcan")
	if host.s.mode not in ["playing","dialogue"]: return _fail("wrong_mode")
	if host.s.get("bossKind","") == "kingdom": return _fail("active_boss")
	if not _placed.get(id,false): return _fail("placement_pending")
	if host.player_center().distance_squared_to(Vector2(row.x,row.y)) >= 2500.0: return _fail("out_of_reach")
	var spatial: Object = _object(_spatial_ref,&"can_reach_target")
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	if spatial == null or spatial.call(&"can_reach_target",id) != true: return _fail("out_of_reach")
	if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return _fail("replaced_state")
	if float(row.get("cdT",0)) > 0:
		_toast("the can is empty.\nyou kick it anyway.\nit barely moves.",1500)
		return {"ok":true,"committed":false}
	row.cdT = 60000.0; row.tipT = 200.0; row.rotPulse = 200.0
	_sound("kick"); host.s.shake = maxf(float(host.s.get("shake",0)),3.0)
	var roll: float = host.random_float()
	var effect: String = "rats"
	if roll < 0.5:
		var amount: int = 2+host.random_index(4)
		host.p.cash += amount; _sound("coin")
		_toast("- nothing\n+ $%d\nthe can falls. coins spill." % amount,2200)
		effect = "cash"
	elif roll < 0.7:
		inventory.append_item("junk","a piece of junk")
		_toast("+ a piece of junk.\npete will take it. for one dollar.",2400)
		effect = "junk"
	elif roll < 0.8:
		inventory.append_item("food","a can of food (unmarked)")
		_toast("+ a can of food (unmarked).\nthe label is in a language.\nthe language is not yours.",2600)
		effect = "food"
	else: _toast("the rats are upset. they have lives.",2000)
	host.emit_event("interactive_prop_effect",{"id":id,"effect":effect,"count":6 if effect == "cash" else (8 if effect == "rats" else 0)})
	_changed(id); host.emit_event("save_requested")
	host.emit_event("gesture",{"action":"kick"})
	return {"ok":true,"committed":true,"effect":effect}

func resolve_swing(capability: Variant) -> Dictionary:
	if not ready(): return _fail("missing_dependency")
	var combat: Object = _object(_combat_ref,&"consume_prop_swing")
	if combat == null: return _fail("missing_combat")
	var candidates: Array[Dictionary] = []
	for index: int in range(6,14):
		var id := "interactive:%d" % index
		var row: Dictionary = _record(id)
		if row.get("broken",false) or not _placed.get(id,false) or _pending.has(id): continue
		candidates.append({"id":id,"x":float(row.x)-4.0,"y":float(row.y)-12.0,"w":8.0,"h":16.0})
	var receipt: Dictionary = combat.call(&"consume_prop_swing",capability,candidates,self)
	if not receipt.get("ok",false): return receipt
	var broken: Array[String] = []
	for id: String in receipt.hits:
		var row: Dictionary = _record(id)
		if row.is_empty() or row.get("type") != "b_bottle" or row.get("broken",false) or not _placed.get(id,false) or _pending.has(id): continue
		row.broken = true; row.respawnT = 60000.0+host.random_float()*60000.0
		_sound("glassBreak"); host.emit_event("interactive_prop_effect",{"id":id,"effect":"glass","count":12})
		var chance: float = host.random_float() # Source rolls even when already equipped.
		if chance < 0.25 and host.p.weapon != "broken_bottle":
			host.p.weapon = "broken_bottle"
			var title: String = host.content.catalogs.weapons.broken_bottle.n
			_toast("+ "+title+"\n(equipped.)")
			host.emit_event("feed",{"text":"picked up "+title+". things are escalating.","author":"@crackheadcent"})
			host.emit_event("gesture",{"action":"equip"})
		_changed(id); broken.append(id)
	return {"ok":true,"broken":broken}

func tick(dt_ms: float) -> bool:
	if not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50 or not ready() or host.s.mode != "playing": return false
	var player_epoch: Dictionary = host.p; var state_epoch: Dictionary = host.s
	# Retry prior intents before authoring new expiry intents, never twice in one tick.
	for id: String in _pending.keys():
		_pending[id].retry_ms -= dt_ms
		if _pending[id].retry_ms <= 0:
			_pending[id].retry_ms = 250.0
			_stage(id)
			if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return false
	for index: int in range(14):
		var id := "interactive:%d" % index
		var row: Dictionary = _record(id)
		if row.type == "trashcan":
			var was_empty: bool = float(row.get("cdT",0)) > 0
			for key: String in ["cdT","tipT","rotPulse"]:
				if float(row.get(key,0)) > 0: row[key] -= dt_ms
			if was_empty and row.cdT <= 0: _changed(id)
		elif row.get("broken",false) and not _pending.has(id):
			row.respawnT -= dt_ms
			if row.respawnT <= 0:
				var point: Vector2 = PropState.BOTTLE_INITIAL_POINTS[host.random_index(12)]
				var x: float = float(point.x)+(host.random_float()-0.5)*40.0
				var y: float = float(point.y)+(host.random_float()-0.5)*40.0
				_pending[id] = {"point":Vector2(x,y),"respawn":true,"retry_ms":250.0}
				_placed.erase(id); _stage(id)
				if not is_same(player_epoch,host.p) or not is_same(state_epoch,host.s): return false
	return true

func render_record(id: String) -> Dictionary:
	if not _same_epoch() or not id.begins_with("interactive:"): return {}
	var suffix: String = id.trim_prefix("interactive:")
	if not suffix.is_valid_int(): return {}
	var index: int = int(suffix)
	if index < 0 or index >= 14 or str(index) != suffix: return {}
	var row: Dictionary = _record(id).duplicate(true)
	if row.is_empty(): return {}
	row.id = id; row.index = index; row.placed = _placed.get(id,false); row.pending = _pending.has(id)
	return row

func render_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _same_epoch(): return result
	for index: int in range(14):
		var id := "interactive:%d" % index
		var row: Dictionary = render_record(id)
		if row.is_empty(): return []
		result.append(row)
	return result
func snapshot() -> Dictionary:
	return {"pending":_pending.keys().duplicate(),"placed_count":_placed.size()} if _same_epoch() else {}
