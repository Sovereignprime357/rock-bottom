class_name RockBottomAmbientAudio
extends RefCounted
## One source ambient clock, independent presentation RNG, no gameplay random draws.
const SourceAudio = preload("res://scripts/source_audio.gd")
var _host_ref: WeakRef
var _player_epoch: Dictionary = {}
var _state_epoch: Dictionary = {}
var _seed: int = 0x414d4249
var _draws: int = 0
var host: RefCounted:
	get: return _host_ref.get_ref() if _host_ref != null else null
func _init(owner: RefCounted,cosmetic_seed: int = 0x414d4249) -> void:
	_host_ref = weakref(owner); _seed = cosmetic_seed&0xffffffff; reset_session("cold")
func _bound() -> bool: return host != null and is_same(host.p,_player_epoch) and is_same(host.s,_state_epoch)
func _number(value: Variant,fallback: float) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
func _roll() -> float:
	_seed = SourceAudio.next_seed(_seed); _draws += 1; return float(_seed)/4294967296.0
func reset_session(kind: String) -> bool:
	if host == null or kind not in ["cold","fresh","restore"]: return false
	if kind != "cold" and not _state_epoch.is_empty():
		if _state_epoch.has("ambientT"): host.s.ambientT = _number(_state_epoch.ambientT,0)
		else: host.s.erase("ambientT")
	_player_epoch = host.p; _state_epoch = host.s; return true
func tick_active(dt_ms: float) -> bool:
	if not _bound() or not is_finite(dt_ms) or dt_ms <= 0 or dt_ms > 50: return false
	var remaining: float = _number(host.s.get("ambientT"),4000)
	if remaining == 0: remaining = 4000 # Source uses|| rather than nullish fallback.
	remaining -= dt_ms; host.s.ambientT = remaining
	if remaining > 0: return true
	host.s.ambientT = 3500+_roll()*4500
	var roll: float = _roll(); var time: float = _number(host.s.get("dayTime"),0)
	var kind: String
	if time < .25 or time > .75:
		kind = "cricket" if roll < .5 else "dogBark" if roll < .7 else "cough" if roll < .85 else "carDoor"
	else: kind = "traffic" if roll < .4 else "dogBark" if roll < .6 else "cough" if roll < .75 else "carDoor"
	host.emit_event("sound",{"id":kind})
	if _number(host.p.get("wanted"),0) > 0 and _roll() < .3: host.emit_event("sound",{"id":"copSiren"})
	return true
func metrics() -> Dictionary: return {"draws":_draws,"seed":_seed}
