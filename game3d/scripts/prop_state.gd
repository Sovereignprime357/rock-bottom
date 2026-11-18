class_name RockBottomPropState
extends RefCounted
## Live source PROPS. Save projection is s.lootedDumpsters; content stays immutable.
var _host_ref: WeakRef
var _records: Array[Dictionary] = []
var _state_epoch: Dictionary = {}
var _interactive: Array[Dictionary] = []
var _interactive_player: Dictionary = {}
var _interactive_state: Dictionary = {}
const BOTTLE_INITIAL_POINTS := [Vector2(140,300),Vector2(680,240),Vector2(1100,540),Vector2(1740,520),
	Vector2(240,980),Vector2(900,1100),Vector2(1500,1240),Vector2(1700,1180),Vector2(320,1420),
	Vector2(540,1700),Vector2(1100,1640),Vector2(1380,1700),Vector2(920,1820),Vector2(280,1820),Vector2(1700,920),Vector2(1820,1380)]
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null

func _init(owner: RefCounted) -> void:
	_host_ref = weakref(owner)
	for value: Variant in owner.content.get("props",[]):
		if value is Dictionary: _records.append(value.duplicate(true))
	reset_session("cold")
	reset_interactive("cold")
func ready() -> bool:
	return host != null and not _records.is_empty() and _records.size() == host.content.get("props",[]).size() and is_same(_state_epoch,host.s)
func records() -> Array[Dictionary]: return _records.duplicate(true)
func interactive_ready() -> bool:
	return ready() and _interactive.size() == 14 and is_same(_interactive_player,host.p) and is_same(_interactive_state,host.s)
func interactive_records() -> Array[Dictionary]: return _interactive.duplicate(true) if interactive_ready() else []
func interactive_record(id: String) -> Dictionary:
	if not interactive_ready() or not id.begins_with("interactive:"): return {}
	var suffix: String = id.trim_prefix("interactive:")
	if not suffix.is_valid_int(): return {}
	var index: int = int(suffix)
	return _interactive[index] if index >= 0 and index < 14 and str(index) == suffix else {}
func reset_interactive(reason: String) -> bool:
	if not ready() or reason not in ["cold","fresh","restore"]: return false
	# Root invokes this explicit seam at the source initInteractiveProps position.
	# Repeated bindings of the same state cannot consume another24 draws.
	if interactive_ready(): return true
	var initial: Variant = host.content.get("interactiveProps",[])
	if not initial is Array or initial.size() != 14: return false
	for index: int in range(14):
		if not initial[index] is Dictionary or initial[index].get("type") != ("trashcan" if index < 6 else "b_bottle"): return false
	var next: Array[Dictionary] = []
	for index: int in range(14):
		if reason == "cold" or index < 6: next.append(initial[index].duplicate(true))
		else:
			var point: Vector2 = BOTTLE_INITIAL_POINTS[host.random_index(BOTTLE_INITIAL_POINTS.size())]
			next.append({"type":"b_bottle","x":float(point.x)+(host.random_float()-0.5)*40.0,"y":float(point.y)+(host.random_float()-0.5)*40.0,"broken":false})
	_interactive = next; _interactive_player = host.p; _interactive_state = host.s
	return true
func _index(id: String) -> int:
	if not id.begins_with("prop:"): return -1
	var suffix: String = id.trim_prefix("prop:")
	if not suffix.is_valid_int(): return -1
	var index: int = int(suffix)
	return index if index >= 0 and index < _records.size() and str(index) == suffix else -1
func record(id: String) -> Dictionary:
	var index: int = _index(id)
	return _records[index] if ready() and index >= 0 else {}
func _coordinate(value: Variant) -> String:
	var number: float = float(value)
	return str(int(number)) if floor(number) == number else String.num(number,12)
func _key(body: Dictionary) -> String: return _coordinate(body.x)+","+_coordinate(body.y)
func _project_looted() -> void:
	var looted: Array[String] = []
	for body: Dictionary in _records:
		if body.get("type") == "dumpster" and body.get("looted",false) == true: looted.append(_key(body))
	host.s.lootedDumpsters = looted
func reset_session(reason: String) -> bool:
	if host == null or reason not in ["cold","fresh","restore"]: return false
	if reason in ["cold","restore"]:
		var saved: Variant = host.s.get("lootedDumpsters",[])
		if saved is Array:
			for body: Dictionary in _records:
				if body.get("type") == "dumpster" and _key(body) in saved: body.looted = true
	# Source new-game preserves PROPS and load only overlays true looted rows.
	_state_epoch = host.s
	host.s.propRuntime = _records
	_project_looted()
	return true
func set_dumpster_looted(id: String,value: bool) -> bool:
	var body := record(id)
	if body.is_empty() or body.get("type") != "dumpster": return false
	body.looted = value; _project_looted()
	host.emit_event("prop_changed",{"id":id})
	return true
func garbage_reset() -> Dictionary:
	if not ready(): return {"ok":false,"reason":"props_unavailable"}
	var indices: Array[int] = []
	for index: int in range(_records.size()):
		if _records[index].get("type") == "dumpster":
			_records[index].looted = false; indices.append(index)
	_project_looted()
	var selected: String = ""
	if not indices.is_empty():
		var index: int = indices[host.random_index(indices.size())]
		_records[index].tipsJar = true
		selected = "prop:%d" % index
	host.emit_event("props_reset",{"kind":"dumpster","tips_jar":selected})
	return {"ok":true,"tips_jar":selected,"count":indices.size()}
