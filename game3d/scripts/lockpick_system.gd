class_name RockBottomLockpick
extends RefCounted
## Shared untimed source puzzle. Callers own menus, capabilities and outcome callbacks.
var _host_ref: WeakRef
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
var _context: String = ""
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _target: Array[int] = []
var _pins: Array[bool] = []
var _next_pin: int = 0

func _init(owner: RefCounted) -> void: _host_ref = weakref(owner)
func active(context: String) -> bool:
	return host != null and not context.is_empty() and context == _context and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func begin(context: String) -> bool:
	if host == null or context.is_empty(): return false
	_context = context; _player_epoch = host.p; _state_epoch = host.s
	_target = draw_order(); _pins.assign([false,false,false,false]); _next_pin = 0
	return true
func cancel(context: String) -> void:
	if context != _context: return
	_context = ""; _player_epoch = {}; _state_epoch = {}; _target.clear(); _pins.clear(); _next_pin = 0
func snapshot(context: String) -> Dictionary:
	if not active(context): return {}
	var display: Array[String] = []
	for set_pin: bool in _pins: display.append("[●]" if set_pin else "[ ]")
	return {"pins":_pins.duplicate(),"next_pin":_next_pin,"title":"LOCKPICK",
		"text":"the lock has 4 pins.\npush them in the right order.\n\n"+" ".join(display)+"\n\n(it makes a small click when you guess right.)"}
func choose(context: String,pin: int) -> Dictionary:
	if not active(context): return {"ok":false,"reason":"stale_puzzle"}
	if pin < 1 or pin > 4: return {"ok":false,"reason":"invalid_pin"}
	if _target[_next_pin] == pin:
		_pins[pin-1] = true; _next_pin += 1; host.emit_event("sound",{"id":"pickup"})
		if _next_pin == 4:
			cancel(context); return {"ok":true,"complete":true}
	else:
		host.emit_event("sound",{"id":"hurt"}); _pins.assign([false,false,false,false]); _next_pin = 0
		host.p.brain = maxf(0,host.p.brain-2)
		host.emit_event("toast",{"text":"CLUNK. all pins reset.\n- 2 brain","duration_ms":1400})
	return {"ok":true,"complete":false}
func draw_order() -> Array[int]:
	# HEIST-V8-SORT: exact approved bounded comparator schedule, not a uniform shuffle.
	var values: Array[int] = [1,2,3,4]
	var run: int = 2
	var descending: bool = host.random_float() < 0.5
	while run < 4:
		if (host.random_float() < 0.5) != descending: break
		run += 1
	if descending:
		for index: int in range(int(run/2.0)):
			var temporary: int = values[index]; values[index] = values[run-1-index]; values[run-1-index] = temporary
	for index: int in range(run,4):
		var pivot: int = values[index]
		var left: int = 0; var right: int = index
		while left < right:
			var middle: int = int(floor((left+right)/2.0))
			if host.random_float() < 0.5: right = middle
			else: left = middle+1
		values.remove_at(index); values.insert(left,pivot)
	return values
