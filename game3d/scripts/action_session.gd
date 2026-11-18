class_name RockBottomActionSession
extends RefCounted
## Ephemeral menu capability. Every selection obtains a new live geometry answer.
var _host_ref: WeakRef
var _spatial_ref: WeakRef
var _spatial_method: StringName
var _serial: int = 0
var _token: String = ""
var _target: String = ""
var _actions: Array[String] = []
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}


func _init(owner: RefCounted, spatial_adapter: Object, spatial_method: StringName = &"can_reach_target") -> void:
	_host_ref = weakref(owner)
	_spatial_ref = weakref(spatial_adapter) if spatial_adapter != null else null
	_spatial_method = spatial_method


func probe(target: String) -> Dictionary:
	var owner: RefCounted = _host_ref.get_ref()
	if owner == null: return {"ok":false, "reason":"missing_owner"}
	var adapter: Object = _spatial_ref.get_ref() if _spatial_ref != null else null
	if adapter == null or not adapter.has_method(_spatial_method): return {"ok":false, "reason":"missing_spatial_adapter"}
	var result: Variant = adapter.call(_spatial_method, target)
	return {"ok":true} if result is bool and result else {"ok":false, "reason":"out_of_reach"}


func begin(target: String, action_ids: Array[String]) -> Dictionary:
	close()
	var reach: Dictionary = probe(target)
	if not reach.ok: return reach
	var owner: RefCounted = _host_ref.get_ref()
	_serial += 1
	_token = "%d:%d" % [get_instance_id(), _serial]
	_target = target
	_actions = action_ids.duplicate()
	_player_epoch = owner.p
	_state_epoch = owner.s
	return {"ok":true, "token":_token}


func consume(token: Variant, action_id: String) -> Dictionary:
	if not token is String or _token.is_empty() or token != _token: return {"ok":false, "reason":"stale_session"}
	var owner: RefCounted = _host_ref.get_ref()
	var target: String = _target
	var offered: bool = _actions.has(action_id)
	var same_epoch: bool = owner != null and is_same(owner.p, _player_epoch) and is_same(owner.s, _state_epoch)
	close() # Consume before any adapter or command can re-enter selection.
	if not same_epoch: return {"ok":false, "reason":"replaced_state"}
	if not offered: return {"ok":false, "reason":"unknown_action"}
	var reach: Dictionary = probe(target)
	if not reach.ok: return reach
	return {"ok":true, "target":target}


func close() -> void:
	_token = ""
	_target = ""
	_actions.clear()
	_player_epoch = {}
	_state_epoch = {}
