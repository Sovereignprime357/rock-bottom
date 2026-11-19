extends SceneTree
## Actual full-scene input/audio/composition. Does not claim a human listening test.
const Scene = preload("res://scripts/full_scene.gd")
const Content = preload("res://scripts/content_catalog.gd")
class MemoryStore:
	extends "res://scripts/save_store.gd"
	func write_save(_data: Dictionary) -> bool: return true
	func read_save() -> Dictionary: return {}
var game: Node3D
var checks: int = 0
var groups: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.pressed = true; event.physical_keycode = code
	game._unhandled_input(event)
func _stop() -> void:
	for voice: AudioStreamPlayer in game.sound.players: voice.stop(); voice.stream = null
func _wait_wall(milliseconds: int) -> void:
	# The runner may use --fixed-fps: SceneTreeTimer then follows simulated frame
	# delta, not the real monotonic clock used by production audio. Yield frames
	# until that actual clock reaches the deadline; never alter the recipe delay.
	var deadline: int = Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec() < deadline: await process_frame
func _place(point: Vector3) -> void:
	var center: Vector2 = Content.to_source(point)
	game.runtime.p.x = center.x-game.runtime.p.w*.5; game.runtime.p.y = center.y-game.runtime.p.h*.5
	game._sync_player()
func _cue_playing(kind: String) -> bool:
	var key: String = game.sound._plans[kind][0][0].clip
	for voice: AudioStreamPlayer in game.sound.players:
		if voice.playing and voice.stream == game.sound._clips[key]: return true
	return false
func _input_gate() -> void:
	_check(not game.sound.ready_for_sound and game.sound.metrics().started == 0,"cold title has no audio before interaction")
	_check(game.sound.metrics().recipes == 24 and game.sound.players.size() == 32,"actual full scene owns the24-recipe source synth")
	game._resume()
	_check(not game.sound.ready_for_sound,"programmatic resume does not unlock sound")
	game.runtime.state.emit_event("sound",{"id":"hurt"}); game._consume_events()
	_check(game.sound.metrics().started == 0 and game.sound.metrics().suppressed > 0,"real model cue remains suppressed before user input")
	game._title()
	_check(game.hud.activate_choice(0) and game.sound.ready_for_sound and game.runtime.s.mode == "playing","actual wake-up button unlocks before invoking new-game callback")
	_stop(); var before: int = game.sound.metrics().started
	_key(KEY_M); game.runtime.state.emit_event("sound",{"id":"hurt"}); game._consume_events()
	_check(game.sound.muted and game.sound.metrics().started == before,"M gates real source cue")
	_key(KEY_M); game.runtime.state.emit_event("sound",{"id":"hurt"}); game._consume_events()
	_check(not game.sound.muted and _cue_playing("hurt"),"M unmute restores original source hurt PCM")
	groups += 1
func _choice_gate() -> void:
	_stop(); game.runtime.set_mode("dialogue"); game._begin_menu()
	var called: Array[int] = [0]; var heard_at_callback: Array[int] = [-1]
	var disabled: Dictionary = game._option("unavailable",func(): called[0] += 1,true)
	game.sound.ready_for_sound = false; var before: Dictionary = game.sound.metrics()
	disabled.action.call()
	_check(called[0] == 0 and not game.sound.ready_for_sound and game.sound.metrics() == before,"disabled UI callback cannot unlock/beep/mutate")
	var stale: Dictionary = game._option("stale",func(): called[0] += 1)
	game._begin_menu(); stale.action.call()
	_check(called[0] == 0 and not game.sound.ready_for_sound and game.sound.metrics() == before,"stale generation cannot unlock or beep")
	var loading: Dictionary = game._option("wait",func(): called[0] += 1)
	game.loading = true; loading.action.call(); game.loading = false
	_check(called[0] == 0 and not game.sound.ready_for_sound and game.sound.metrics() == before,"loading UI callback cannot unlock or beep")
	var accepted: Dictionary = game._option("leave.",func():
		heard_at_callback[0] = game.sound.metrics().started; called[0] += 1; game._resume())
	game.hud.menu("THE DOOR","",[disabled,accepted])
	_key(KEY_1)
	_check(called[0] == 0 and game.sound.metrics().started == before.started,"real disabled numbered choice makes no click cue")
	_key(KEY_9)
	_check(called[0] == 0 and game.sound.metrics().started == before.started,"out-of-range numbered choice makes no click cue")
	_key(KEY_2)
	_check(called[0] == 1 and heard_at_callback[0] == before.started+1 and _cue_playing("dialogue"),"enabled numbered leave beeps exactly once before callback")
	_check(game.runtime.s.mode == "playing" and not game.hud.modal.visible,"source leave closes after audio acknowledgment")
	game.runtime.set_mode("dialogue"); game._begin_menu()
	game.hud.menu("THE DOOR","",[game._option("leave.",game._resume)])
	var started: int = game.sound.metrics().started; _key(KEY_ESCAPE)
	_check(game.runtime.s.mode == "playing" and game.sound.metrics().started == started,"Escape closes without a source option beep")
	groups += 1
func _ambient_clock() -> void:
	game.runtime.fresh(); game._resume(); game.runtime.drain_events()
	game.runtime.s.ambientT = 4000; var owner_id: int = game.runtime.ambient_audio.get_instance_id()
	var draws: int = game.runtime.ambient_audio.metrics().draws
	game.runtime.advance(.05)
	_check(absf(game.runtime.s.ambientT-3950) < .00001 and game.runtime.ambient_audio.metrics().draws == draws,"full fixed-step pipeline advances exactly one source ambient clock")
	for mode: String in ["paused","dialogue","title"]:
		game.runtime.set_mode(mode); var timer: float = game.runtime.s.ambientT
		game.runtime.advance(.1)
		_check(game.runtime.s.ambientT == timer,"ambient clock freezes in "+mode)
	game.runtime.set_mode("playing"); game.runtime.s.hitPause = 50
	var timer: float = game.runtime.s.ambientT; game.runtime.advance(.05)
	_check(game.runtime.s.ambientT == timer,"whole source hitpause skips ambient clock")
	game.runtime.s.hitPause = 0; game.runtime.s.ambientT = 1234
	_check(game.runtime.fresh() and game.runtime.s.ambientT == 1234,"composed fresh carries source session ambientT")
	var saved: Dictionary = game.runtime.snapshot()
	_check(not saved.state.has("ambientT"),"full save has no duplicate persistent ambient timer")
	_check(game.runtime.restore(saved) and game.runtime.s.ambientT == 1234 and game.runtime.ambient_audio.get_instance_id() == owner_id,"composed restore rebinds same audio owner with source carried timer")
	game.runtime.s.ambientT = 1; game.runtime.p.wanted = 0
	draws = game.runtime.ambient_audio.metrics().draws
	game.runtime.advance(.001)
	_check(game.runtime.ambient_audio.metrics().draws == draws+2 and game.runtime.s.ambientT >= 3500 and game.runtime.s.ambientT < 8000,"one expiration rolls exactly one independent ambient event")
	var ambient_ids: Array[String] = []
	for event: Dictionary in game.runtime.drain_events():
		if event.kind == "sound" and event.payload.get("id") in ["traffic","cricket","dogBark","cough","carDoor"]: ambient_ids.append(event.payload.id)
	_check(ambient_ids.size() == 1,"one model cue for one ambient clock expiry")
	groups += 1
func _wall_and_lifecycle() -> void:
	_stop(); game.runtime.set_mode("paused"); game.sound.ready_for_sound = true; game.sound.muted = false
	game._process(0)
	_check(game.sound._wall == game.runtime._wall_ms,"Scene advances sound and runtime with same monotonic wall value:audio=%s runtime=%s"%[game.sound._wall,game.runtime._wall_ms])
	var timer: float = game.runtime.s.ambientT; var queued: int = game.sound.metrics().queued
	game.runtime.state.emit_event("sound",{"id":"pickup"}); game._consume_events()
	_check(_cue_playing("pickup") and game.sound.metrics().queued == queued+1,"real source ID starts first pickup and queues second")
	var before: int = game.sound.metrics().started
	await _wait_wall(80); game._process(.01)
	_check(game.sound.metrics().started == before+1 and game.runtime.s.ambientT == timer,"second source note fires by wall while world remains paused:started=%s expected=%s timer=%s expected=%s pending=%s"%[game.sound.metrics().started,before+1,game.runtime.s.ambientT,timer,game.sound.metrics().queued])
	_stop(); game.runtime.state.emit_event("audio",{"id":"rockUp"}); game._consume_events()
	_check(game.sound.metrics().queued == 4,"rockUp retains four source delayed notes without slice alias:queued=%s"%game.sound.metrics().queued)
	var sound_id: int = game.sound.get_instance_id()
	_check(game.runtime.fresh() and game.sound.metrics().queued == 4,"fresh leaves source setTimeout-equivalent notes queued")
	var saved: Dictionary = game.runtime.snapshot()
	_check(game.runtime.restore(saved) and game.sound.metrics().queued == 4 and game.sound.get_instance_id() == sound_id,"restore retains same audio node and pending notes")
	game.runtime.set_mode("title"); before = game.sound.metrics().started
	await _wait_wall(340); game._process(0)
	_check(game.sound.metrics().queued == 0 and game.sound.metrics().started == before+4,"title-mode wall pump finishes all retained high notes exactly once:queued=%s started=%s expected=%s"%[game.sound.metrics().queued,game.sound.metrics().started,before+4])
	groups += 1
func _high_crash() -> void:
	game.runtime.fresh(); game._resume(); _place(game.world.service_points["smoke:block"].approach)
	game.runtime.p.rocks = 1; game.runtime.p.shakes = 60; game.runtime.p.iframes = 1000000
	game.runtime.drain_events(); _stop()
	game._zone_menu("block"); _key(KEY_1)
	_check(game.runtime.p.rockedT == 18000 and game.runtime.p.rocks == 0 and game.sound.metrics().queued == 4,"real Block choice consumes one rock and starts source four-note high")
	var started: int = game.sound.metrics().started
	await _wait_wall(340); game._process(0)
	_check(game.sound.metrics().queued == 0 and game.sound.metrics().started == started+4 and game.runtime.p.rockedT == 18000,"all four source high notes play on wall time without advancing the model:queued=%s started=%s expected=%s high=%s"%[game.sound.metrics().queued,game.sound.metrics().started,started+4,game.runtime.p.rockedT])
	# Advance the real full model with all56+ actors; large iframes isolate audio/timer
	# evidence from unrelated incoming damage, without replacing AI or the high hook.
	game.runtime.advance(17.99); game.runtime.drain_events()
	_check(absf(game.runtime.p.rockedT-10) < .0001,"actual18s high remains active until final10ms")
	_stop(); game.runtime.advance(.01); game._consume_events()
	_check(game.runtime.p.rockedT == 0 and absf(game.runtime.p.crashT-8000) < .0001,"real high hook enters exact8s normal crash once")
	_check(_cue_playing("crash"),"high expiry dispatches source600ms saw crash instead of short slice PCM")
	game.runtime.advance(8.0); game.runtime.drain_events()
	_check(game.runtime.p.crashT == 0,"actual8s crash completes without a duplicate audio timer")
	groups += 1
func _run() -> void:
	game = Scene.new(); root.add_child(game); game.qa_mode = true
	for frame: int in range(500):
		await process_frame
		if game.ready_for_play: break
	_check(game.ready_for_play,"real full scene reaches title")
	if not game.ready_for_play: await _finish(); return
	game.set_process(false); game.qa_mode = true; game.web_controls = false
	game.store.free(); game.store = MemoryStore.new(); game.add_child(game.store)
	_input_gate(); _choice_gate(); _ambient_clock(); await _wall_and_lifecycle(); await _high_crash()
	await _finish()
func _finish() -> void:
	_check(groups == 5,"all5actual-input/choice/ambient/wall/high-crash groups completed")
	if game != null and game.sound != null: _stop()
	await _wait_wall(100)
	if game != null: game.free(); game = null
	await process_frame; await process_frame
	if failures.is_empty() and checks >= 35:
		print("3D AUDIO RUNTIME GATE: PASS (%d checks;actual FullScene input/ambient/wall/fresh/restore/18s8s loop)" % checks); quit(0)
	else:
		for failure: String in failures: push_error(failure)
		print("3D AUDIO RUNTIME GATE: FAIL (%d/%d checks;groups%d/5)" % [failures.size(),checks,groups]); quit(1)
