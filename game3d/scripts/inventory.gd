class_name RockBottomInventory
extends RefCounted
## Source record semantics, with a narrow schema1 virtual-unit compatibility marker.
var _host_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var _known_ids: Dictionary = {}


func _init(owner: RefCounted) -> void:
	_host_ref = weakref(owner)
	for item: Dictionary in owner.content.get("catalogs", {}).get("items", []):
		_known_ids[str(item.id)] = true


func _positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0 and floor(float(value)) == float(value) and float(value) <= 1000000000.0


func _units(item: Dictionary) -> int:
	if item.get("id") in ["junk", "food"] and item.get("migration_units") is bool and item.migration_units:
		return int(item.q) if _positive_integer(item.get("q")) else 0
	return 1


func count_records(id: String) -> int:
	var count: int = 0
	if host == null: return count
	for item: Dictionary in host.p.inventory:
		if item.get("id") == id: count += _units(item)
	return count


func quantity(id: String) -> int:
	var count: int = 0
	if host == null: return count
	for item: Dictionary in host.p.inventory:
		if item.get("id") == id and _positive_integer(item.get("q", 1)): count += int(item.get("q", 1))
	return count


func append_item(id: String, item_name: String, quantity_value: Variant = 1) -> bool:
	if host == null or not _known_ids.has(id) or not _positive_integer(quantity_value): return false
	if item_name.is_empty() or item_name.length() > 512: return false
	host.p.inventory.append({"id":id, "n":item_name, "q":int(quantity_value)})
	return true


func remove_first_record(id: String) -> int:
	return remove_records(id, 1)


func remove_records(id: String, requested: Variant) -> int:
	if host == null or not _positive_integer(requested) or count_records(id) < int(requested): return 0
	var remaining: int = int(requested)
	var kept: Array[Dictionary] = []
	for item: Dictionary in host.p.inventory:
		if item.get("id") != id or remaining == 0:
			kept.append(item)
			continue
		var units: int = _units(item)
		var taken: int = mini(remaining, units)
		remaining -= taken
		if taken < units:
			# Only migration stacks can represent multiple source records.
			item.q = units - taken
			kept.append(item)
	host.p.inventory = kept
	return int(requested)


func remove_all(id: String) -> int:
	if host == null: return 0
	var removed: int = 0
	var kept: Array[Dictionary] = []
	for item: Dictionary in host.p.inventory:
		if item.get("id") == id: removed += _units(item)
		else: kept.append(item)
	host.p.inventory = kept
	return removed


func owns_tool(id: String) -> bool:
	return host != null and id in ["propane_torch", "crowbar"] and (host.p.equip.get("tool") == id or host.s.flags.get("peteToolLocker") == id)


func swap_locker() -> Dictionary:
	if host == null: return {"ok":false, "reason":"missing_owner"}
	var held: Variant = host.s.flags.get("peteToolLocker")
	var returned: Variant = host.p.equip.get("tool")
	if held not in ["propane_torch", "crowbar"] or held == returned: return {"ok":false, "reason":"empty_locker"}
	host.s.flags.peteToolLocker = returned
	host.p.equip.tool = held
	host.apply_equip_stats()
	return {"ok":true, "held":held, "returned":returned}
