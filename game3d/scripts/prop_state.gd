class_name RockBottomPropState
extends RefCounted
## Live source PROPS. Save projection is s.lootedDumpsters; content stays immutable.
var _host_ref: WeakRef
var _records: Array[Dictionary] = []
var _state_epoch: Dictionary = {}
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null

func _init(owner: RefCounted) -> void:
	_host_ref = weakref(owner)
	for value: Variant in owner.content.get("props",[]):
		if value is Dictionary: _records.append(value.duplicate(true))
	reset_session("cold")
func ready() -> bool:
	return host != null and not _records.is_empty() and _records.size() == host.content.get("props",[]).size() and is_same(_state_epoch,host.s)
func records() -> Array[Dictionary]: return _records.duplicate(true)
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
